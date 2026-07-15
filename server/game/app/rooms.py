"""배틀 방: 상태머신 + B-lite 텍스트 릴레이 (FSD 3.2.3).

상태: matched → briefing → in_call → judging → done (+ aborted).
인메모리 Room이 런타임 진실, DB(battle_rooms)는 기록. 발화는 t_start_ms 기준
저장(규칙 #3) — 인크리멘탈 심판 트리거(P1)는 TODO 지점에 표시.
"""

import asyncio
import json
import random
import time
import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from . import db, llm, scenarios
from .auth import user_id_from_token

router = APIRouter()


async def _run_judge_llm(prompt: str, task: str = "final_judge",
                         max_output_tokens: int = 1024) -> str:
    """llm.py 프록시 파이프라인 인프로세스 재사용 (task별 백엔드 분기 —
    final_judge=Gemini, incremental=vLLM). /llm/chat을 우회하므로 llm_logs
    기록도 여기서 동일하게 남긴다(QLoRA 데이터)."""
    req = llm.ChatRequest(
        task=task,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
        max_output_tokens=max_output_tokens,
    )
    backend = llm._backend_for(req.task)
    stream = llm._stream_vllm(req) if backend == "vllm" else llm._stream_gemini(req)
    started = time.monotonic()
    full = "".join([delta async for delta in stream])
    if db.pool:
        await db.pool.execute(
            "INSERT INTO llm_logs (task, model, session_id, request, response, latency_ms)"
            " VALUES ($1, $2, $3, $4, $5, $6)",
            req.task, backend, None,
            json.dumps(req.messages, ensure_ascii=False),
            json.dumps({"text": full}, ensure_ascii=False),
            int((time.monotonic() - started) * 1000),
        )
    return full


def _extract_json(raw: str) -> dict:
    """응답에서 JSON 본문 추출 (```json 펜스·잡담 방어 — 클라 _extractJson과 동일 전략)."""
    start, end = raw.find("{"), raw.rfind("}")
    if start < 0 or end <= start:
        return {}
    try:
        parsed = json.loads(raw[start : end + 1])
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


class Room:
    def __init__(self, room_id: str, players: dict[str, dict], scenario: dict):
        self.id = room_id
        self.state = "matched"
        self.scenario = scenario  # scenarios.py 항목 (situation·roles·판정 규칙)
        self.players = players  # user_id -> {role, form_factor, nickname, brief(dict)}
        self.sockets: dict[str, WebSocket] = {}
        self.spectators: list[WebSocket] = []  # 관전자(읽기 전용) — 비밀 제외 브로드캐스트만
        self.ready: set[str] = set()
        self.started_at: float | None = None  # in_call 진입 (t_start_ms 기준점)
        self.time_limit_s = 300
        self._timer: asyncio.Task | None = None
        self.utterances: list[dict] = []  # 최종 심판용 인메모리 트랜스크립트
        # ---- 인크리멘탈 심판 (FSD §4.2) — 실시간 기세·이벤트·코치 ----
        self.momentum_agent = 50          # agent 관점 0~100 (claimant = 100-값)
        self.judge_seq = 0
        self._judge_events_fired: list[str] = []  # 프롬프트 누적 상태 (이벤트 반복 방지)
        self._judged_upto = 0             # 심판에 반영된 utterances 개수
        self._judge_task: asyncio.Task | None = None
        self._judge_loop: asyncio.Task | None = None

    def t_ms(self) -> int:
        return 0 if self.started_at is None else int((time.monotonic() - self.started_at) * 1000)

    async def broadcast(self, msg: dict) -> None:
        # state·utterance·verdict는 당사자·관전자 모두에게 (비밀 없는 공개 이벤트).
        payload = json.dumps(msg, ensure_ascii=False)
        for ws in list(self.sockets.values()) + list(self.spectators):
            try:
                await ws.send_text(payload)
            except Exception:
                pass

    async def send_spectators(self, msg: dict) -> None:
        payload = json.dumps(msg, ensure_ascii=False)
        for ws in list(self.spectators):
            try:
                await ws.send_text(payload)
            except Exception:
                pass

    def spectator_snapshot(self) -> dict:
        """관전 접속 즉시 현재 상태 스냅샷 (중간 진입 대응).
        데모 관전은 '감독 시점' — 양측 비밀 목표·규칙 카드를 모두 노출한다
        (당사자끼리는 서로 못 보지만 관전 프로젝터에는 다 보이는 게 의도)."""
        return {
            "type": "watch_init",
            "state": self.state,
            "startedAtMs": self.t_ms(),
            "momentum": {
                self.players[uid]["role"]: (
                    self.momentum_agent if self.players[uid]["role"] == "agent"
                    else 100 - self.momentum_agent)
                for uid in self.players
            },
            "situation": self.scenario["situation"],
            "scenarioTitle": self.scenario["title"],
            "players": {
                p["role"]: {
                    "nickname": p["nickname"],
                    "formFactor": p["form_factor"],
                    "roleLabel": p["brief"]["label"],
                    "goal": p["brief"]["goal"],
                    "hardLine": p["brief"]["hard_line"],
                    "secret": p["brief"]["secret"],
                    # 하위호환(관전 화면 기존 필드): 목표/비밀을 secretGoal로 노출
                    "secretGoal": p["brief"]["secret"],
                    "ruleCard": None,
                }
                for p in self.players.values()
            },
            # 지금까지의 발화 (role 표기만 — user_id·비밀 노출 안 함)
            "utterances": [
                {"role": u["role"], "text": u["text"], "tStartMs": u["t_start_ms"]}
                for u in self.utterances
            ],
        }

    async def relay_audio(self, from_user_id: str, data: bytes) -> None:
        """오디오 프레임 pass-through — 저장·가공 없이 상대에게만 즉시 전달 (Phase 2)."""
        for uid, ws in list(self.sockets.items()):
            if uid == from_user_id:
                continue
            try:
                await ws.send_bytes(data)
            except Exception:
                pass

    async def set_state(self, state: str) -> None:
        self.state = state
        await self.broadcast({"type": "state", "state": state})
        if db.pool:
            await db.pool.execute("UPDATE battle_rooms SET state=$2 WHERE id=$1", uuid.UUID(self.id), state)

    async def start_call(self) -> None:
        self.started_at = time.monotonic()
        await self.set_state("in_call")
        if db.pool:
            await db.pool.execute(
                "UPDATE battle_rooms SET started_at=now() WHERE id=$1", uuid.UUID(self.id))
        self._timer = asyncio.create_task(self._time_limit())
        self._judge_loop = asyncio.create_task(self._incremental_ticker())

    async def _time_limit(self) -> None:
        await asyncio.sleep(self.time_limit_s)
        if self.state == "in_call":
            await self.end_call()

    async def end_call(self) -> None:
        if self.state != "in_call":  # 타이머·hang_up 중복 호출 방지
            return
        if self._timer:
            self._timer.cancel()
        if self._judge_loop:
            self._judge_loop.cancel()
        if self._judge_task and not self._judge_task.done():
            self._judge_task.cancel()  # 최종 심판 중 게이지 갱신 방지
        await self.set_state("judging")
        verdict = await self._judge()  # 실패 시 무승부 폴백 — done은 반드시 도달
        await self.broadcast({"type": "verdict", **verdict})
        await self._record(verdict)
        await self.set_state("done")

    # ------------------------------------------------------------ 인크리멘탈 심판
    # FSD §4.2: 새 발화 3개 누적 또는 20초 경과(신규 1개 이상) 시 경량 심판(vLLM).
    # 통화를 막지 않는 비동기 사이드 채널 — 실패해도 게임 진행에 영향 없음.
    async def _incremental_ticker(self) -> None:
        while self.state == "in_call":
            await asyncio.sleep(20)
            self.maybe_incremental(min_new=1, silence_ok=True)

    def maybe_incremental(self, min_new: int = 3, silence_ok: bool = False) -> None:
        if self.state != "in_call":
            return
        if self._judge_task and not self._judge_task.done():
            return  # 단일 비행 — 심판 호출 중첩 방지
        new = len(self.utterances) - self._judged_upto
        # silence_ok(20초 틱): 신규 발화 0개여도 대화가 시작된 뒤라면 침묵 자체를
        # 심판에 넘긴다 — "버티기 전략 실시간 처벌" (FSD §4.3 게이지 목적).
        if new < min_new and not (silence_ok and new == 0 and self.utterances):
            return
        self._judge_task = asyncio.create_task(self._incremental_judge())

    async def _incremental_judge(self) -> None:
        upto = len(self.utterances)
        delta_utts = self.utterances[self._judged_upto:upto]
        try:
            raw = await _run_judge_llm(
                self._incremental_prompt(delta_utts), task="incremental",
                max_output_tokens=256)
            j = _extract_json(raw)
            if not j:
                return  # 파싱 실패 — 이번 델타는 다음 심판에 이월
        except Exception:
            return
        if self.state != "in_call":  # 심판 중 통화가 끝났으면 폐기
            return
        self._judged_upto = upto
        delta = max(-15, min(15, int(j.get("momentumDelta") or 0)))
        # 중간 판정은 5~95로 clamp — 완승/완패 확정은 최종 심판 몫 (FSD §4.4)
        self.momentum_agent = max(5, min(95, self.momentum_agent + delta))
        event = (j.get("event") or "").strip() or None
        if event:
            self._judge_events_fired.append(event)
        self.judge_seq += 1
        at_ms = self.t_ms()
        # 개인화 전송 — 힌트는 본인 몫만 (규칙 #2: 상대 비밀 누설 금지 이중 방어)
        for uid, ws in list(self.sockets.items()):
            role = self.players[uid]["role"]
            try:
                await ws.send_text(json.dumps({
                    "type": "judge",
                    "seq": self.judge_seq,
                    "atMs": at_ms,
                    "momentum": self.momentum_agent if role == "agent"
                                else 100 - self.momentum_agent,
                    "event": event,
                    "hint": (j.get("hintAgent") if role == "agent"
                             else j.get("hintClaimant")) or "",
                    "caster": j.get("caster") or "",  # 당사자 화면은 미표시 (관전용)
                }, ensure_ascii=False))
            except Exception:
                pass
        # 관전자: 힌트 제외, 기세만 (agent 관점 기준값 — 클라가 표시축 결정)
        await self.send_spectators({
            "type": "judge",
            "seq": self.judge_seq,
            "atMs": at_ms,
            "momentumAgent": self.momentum_agent,
            "event": event,
        })
        if db.pool:  # 관전 리플레이·판정 시비 대응 기록 (P1 테이블)
            await db.pool.execute(
                "INSERT INTO judge_events (room_id, seq, at_ms, payload) VALUES ($1,$2,$3,$4)",
                uuid.UUID(self.id), self.judge_seq, at_ms,
                json.dumps({
                    "momentum_agent": self.momentum_agent, "delta": delta,
                    "event": event, "hint_agent": j.get("hintAgent"),
                    "hint_claimant": j.get("hintClaimant"), "caster": j.get("caster"),
                }, ensure_ascii=False))

    def _incremental_prompt(self, delta_utts: list[dict]) -> str:
        a = self.players[self._role_uid("agent")]["brief"]
        c = self.players[self._role_uid("claimant")]["brief"]
        log = "\n".join(
            f"({u['t_start_ms'] // 1000}s) {u['role']}: {u['text']}" for u in delta_utts) \
            or "(지난 20초간 아무도 발화하지 않음 — 침묵이 이어지고 있다)"
        fired = ", ".join(self._judge_events_fired[-5:]) or "없음"
        return f"""너는 전화 협상 배틀 게임 '여보세요'의 실시간 심판이다. 방금 오간 발화만 보고 즉각 판정해 JSON만 출력해라.

[공통 상황] {self.scenario['situation']}
[agent = {a['label']}] 목표: {a['goal']} / 물러설 수 없는 선: {a['hard_line']} / 들키면 안 되는 비밀: {a['secret']}
[claimant = {c['label']}] 목표: {c['goal']} / 물러설 수 없는 선: {c['hard_line']} / 들키면 안 되는 비밀: {c['secret']}
[현재 기세] agent {self.momentum_agent} : claimant {100 - self.momentum_agent}
[이미 발동된 이벤트] {fired}
[새 발화] (초 발화자: 내용)
{log}

규칙:
- momentumDelta: -15~15 정수, agent 관점(+는 agent 우세). 협상 주도권·설득 우위를 가져간 쪽으로. 특기할 것 없으면 0.
- 상대의 비밀을 정확히 짚어 흔든 쪽, 또는 자기 비밀을 스스로 노출해 주도권을 잃은 쪽을 기세에 반영해라.
- 침묵 턴(새 발화 없음)이면: 시간을 끌어 회피하는 쪽에 -5~-2 페널티. 힌트로 침묵을 깰 첫마디를 제안해라.
- event: 결정적 순간이 있을 때만 6자 내외 한 문구("비밀 간파!", "선 넘음 위기", "논리 클린히트"). 이미 발동된 이벤트와 중복 금지. 없으면 null.
- hintAgent / hintClaimant: 각자에게 주는 한 줄 화술 코치. ★상대의 비밀·목표를 절대 누설하지 마라.
- caster: 관전자용 실황 중계 한 줄 (양쪽 비밀 미포함, 스포츠 캐스터 톤).

출력 JSON (다른 텍스트 금지):
{{"momentumDelta": 0, "event": null, "hintAgent": "…", "hintClaimant": "…", "caster": "…"}}"""

    # ---------------------------------------------------------------- 최종 심판
    def _role_uid(self, role: str) -> str | None:
        for uid, p in self.players.items():
            if p["role"] == role:
                return uid
        return None

    def _brief_public(self, brief: dict) -> dict:
        """결과 화면(4c)에서 양측 카드에 그대로 뿌릴 브리핑 필드."""
        return {
            "label": brief["label"],
            "goal": brief["goal"],
            "winNote": brief["win_note"],
            "hardLine": brief["hard_line"],
            "exceptions": brief["exceptions"],
            "secret": brief["secret"],
            "secretGoal": brief["secret"],  # 하위호환
        }

    async def _judge(self) -> dict:
        """전체 트랜스크립트 정밀 심판 — LLM은 settlement(합의 결과)와 과정 점수만
        추출하고, '물러설 수 없는 선' 위반→자동 패배 판정은 코드가 규칙으로 내린다
        (scenarios.decide_winner). LLM 출력 role 키 → 서버가 user_id 키로 변환."""
        try:
            raw = await _run_judge_llm(self._judge_prompt())
            j = _extract_json(raw)
            if not j:
                raise ValueError("empty judge json")
            settlement = j.get("settlement") or {}
            jp_all = j.get("players") or {}

            def score(role: str) -> int:
                v = (jp_all.get(role) or {}).get("goalScore")
                return max(0, min(100, int(v))) if isinstance(v, (int, float)) else 50

            sa, sc = score("agent"), score("claimant")
            winner_role, crossed = scenarios.decide_winner(self.scenario, settlement, sa, sc)
            winner_uid = self._role_uid(winner_role) if winner_role else None
            total = sa + sc or 1
            momentum_by_role = {"agent": round(sa / total * 100)}
            momentum_by_role["claimant"] = 100 - momentum_by_role["agent"]

            players_out = {}
            for uid, p in self.players.items():
                role = p["role"]
                jp = jp_all.get(role) or {}
                line_held = not crossed.get(role, False)
                players_out[uid] = {
                    "role": role,
                    "nickname": p["nickname"],
                    **self._brief_public(p["brief"]),
                    "lineHeld": line_held,
                    "crossedLine": not line_held,
                    "secretExposed": jp.get("secretExposed") is True,
                    "goalScore": score(role),
                    # goalAchieved: 선을 지켰고 목표 점수가 준수하면 달성으로 (DB·기존 UI 호환)
                    "goalAchieved": line_held and score(role) >= 55,
                    "goalNote": jp.get("goalNote") or "",
                    "rubric": jp.get("rubric") or [],
                    "improvement": jp.get("improvement") or {},
                }
            kq = j.get("keyQuote") or {}
            return {
                "winnerUserId": winner_uid,
                "verdictLine": j.get("verdictLine") or "",
                "settlementSummary": settlement.get("summary") or "",
                "momentum": {uid: momentum_by_role[p["role"]] for uid, p in self.players.items()},
                "players": players_out,
                "keyQuote": {
                    "userId": self._role_uid(kq.get("speaker", "")),
                    "text": kq.get("text") or "",
                    "note": kq.get("note") or "",
                },
            }
        except Exception:
            # 심판 불능(LLM 장애 등) — 무승부 폴백으로 클라 진행 보장.
            return {
                "winnerUserId": None,
                "verdictLine": "심판을 완료하지 못했어요 — 무승부로 처리했습니다.",
                "settlementSummary": "",
                "momentum": {uid: 50 for uid in self.players},
                "players": {
                    uid: {
                        "role": p["role"],
                        "nickname": p["nickname"],
                        **self._brief_public(p["brief"]),
                        "lineHeld": None,
                        "crossedLine": None,
                        "secretExposed": None,
                        "goalScore": 50,
                        "goalAchieved": None,
                        "goalNote": "",
                        "rubric": [],
                        "improvement": {},
                    }
                    for uid, p in self.players.items()
                },
                "keyQuote": {},
            }

    def _settlement_spec(self) -> str:
        """이 시나리오의 settlement 추출 지침 (금액·범주·조건)."""
        sc = self.scenario
        lines = ['- dealReached: 거래/합의가 실제로 성사됐으면 true, 결렬·미합의면 false.']
        if sc.get("metric_label"):
            lines.append(f'- metricValue: {sc["metric_label"]}을 정수(원 단위, 예 265000)로. 합의 못 했으면 null.')
        else:
            lines.append('- metricValue: null (이 시나리오는 금액이 없다).')
        if sc.get("categories"):
            cats = " / ".join(f'"{c["key"]}"={c["desc"]}' for c in sc["categories"])
            lines.append(f'- outcomeCategory: 통화 결과를 다음 중 하나로 — {cats}.')
        else:
            lines.append('- outcomeCategory: null.')
        if sc.get("conditions"):
            conds = " / ".join(f'"{c["key"]}"={c["desc"]}' for c in sc["conditions"])
            lines.append(f'- conditionsMet: 실제로 충족된 조건 key들의 배열(없으면 []) — {conds}.')
        else:
            lines.append('- conditionsMet: [].')
        lines.append('- summary: 합의 결과를 짧은 한 줄로(예 "26만 5천원에 직거래 합의" / "정산 결렬").')
        return "\n".join(lines)

    def _judge_prompt(self) -> str:
        def mmss(ms: int) -> str:
            s = ms // 1000
            return f"{s // 60:02d}:{s % 60:02d}"

        def role_block(role: str) -> str:
            b = self.players[self._role_uid(role)]["brief"]
            exc = " ".join(b["exceptions"])
            return (f"[{role} = {b['label']}]\n"
                    f"  목표: {b['goal']} ({b['win_note']})\n"
                    f"  물러설 수 없는 선: {b['hard_line']} 예외: {exc}\n"
                    f"  들키면 안 되는 비밀: {b['secret']}")

        log = "\n".join(
            f"({mmss(u['t_start_ms'])}) {u['role']}: {u['text']}" for u in self.utterances
        ) or "(발화 없음)"
        return f"""너는 전화 협상 배틀 게임 '여보세요'의 최종 심판이다. 아래 통화를 평가해 JSON만 출력해라.
승패(선 위반 = 자동 패배)는 시스템이 규칙으로 계산하므로, 너는 '합의 결과(settlement)'를 정확히 추출하고 과정을 채점만 하면 된다.

[공통 상황] {self.scenario['situation']}
{role_block("agent")}
{role_block("claimant")}
[통화 중 실시간 심판이 포착한 이벤트] {", ".join(self._judge_events_fired) or "없음"}
[통화 기록] (mm:ss 발화자: 내용)
{log}

먼저 통화에서 최종 합의 결과를 추출해라(settlement):
{self._settlement_spec()}

그다음 각 역할을 채점해라:
- goalScore(0~100): 자기 목표를 얼마나 잘 이뤘는가 + 과정(말투·근거·감정 조절). 버티기·시간 끌기는 감점.
- secretExposed: 자기 '들키면 안 되는 비밀'을 상대가 정확히 간파해 파고들었거나 스스로 노출했으면 true.
- goalNote: 판단 근거 한 줄(실제 대사 인용).
- rubric: 역할에 맞는 항목 2~3개 (label, score 1~5, comment는 실제 대사 인용 포함).
- improvement: 서툴렀던 순간 1개 (situation=실제 발화, better=이렇게 말했다면).
- verdictLine: 이 판을 한 줄로 요약한 판정 근거.
- keyQuote: 판을 결정지은 실제 대사 1개.
- 발화가 매우 적으면 dealReached=false, goalScore는 양쪽 모두 45~55로.

출력 JSON 스키마 (다른 텍스트 금지):
{{"settlement": {{"dealReached": bool, "metricValue": number|null, "outcomeCategory": string|null, "conditionsMet": [string], "summary": "…"}},
 "verdictLine": "한 줄 판정 근거",
 "players": {{
   "agent": {{"goalScore": 0-100, "secretExposed": bool, "goalNote": "근거",
             "rubric": [{{"label": "항목", "score": 1-5, "comment": "인용 포함"}}],
             "improvement": {{"situation": "실제 발화", "better": "이렇게 말했다면"}}}},
   "claimant": {{"goalScore": 0-100, "secretExposed": bool, "goalNote": "근거",
                "rubric": [{{"label": "항목", "score": 1-5, "comment": "인용 포함"}}],
                "improvement": {{"situation": "실제 발화", "better": "이렇게 말했다면"}}}}}},
 "keyQuote": {{"speaker": "agent"|"claimant", "text": "실제 대사", "note": "왜 결정적이었는지"}}}}"""

    async def _record(self, verdict: dict) -> None:
        """battle_rooms(승자·기세·판정) + battle_players(목표 달성) 기록."""
        if not db.pool:
            return
        winner_uid = verdict.get("winnerUserId")
        final_momentum = (
            verdict["momentum"].get(winner_uid) if winner_uid else 50
        )  # 스키마 주석: 승자 관점 0~100
        await db.pool.execute(
            "UPDATE battle_rooms SET ended_at=now(), winner_user_id=$2,"
            " final_momentum=$3, verdict=$4 WHERE id=$1",
            uuid.UUID(self.id),
            uuid.UUID(winner_uid) if winner_uid else None,
            final_momentum,
            json.dumps(verdict, ensure_ascii=False),
        )
        for uid, p in verdict["players"].items():
            await db.pool.execute(
                "UPDATE battle_players SET goal_achieved=$3 WHERE room_id=$1 AND user_id=$2",
                uuid.UUID(self.id), uuid.UUID(uid), p.get("goalAchieved"),
            )


rooms: dict[str, Room] = {}


async def create_room(a: dict, b: dict) -> Room:
    """매칭 성사 → 시나리오 랜덤 선택 + 역할(A=agent/B=claimant) 랜덤 배정.
    각 유저에겐 자기 몫 브리핑만 전송한다(규칙 #2 — matching.py)."""
    scenario = scenarios.pick()
    users = [a, b]
    random.shuffle(users)
    roles = ["agent", "claimant"]
    players = {}
    for user, role in zip(users, roles):
        players[user["user_id"]] = {
            **user,
            "role": role,
            "brief": scenario["roles"][role],  # 5필드 브리핑 + 칩 + 첫마디 + 규칙
        }
    room_id = str(uuid.uuid4())
    room = Room(room_id, players, scenario)
    rooms[room_id] = room
    if db.pool:
        await db.pool.execute(
            "INSERT INTO battle_rooms (id, state, scenario, time_limit_s) VALUES ($1,'matched',$2,$3)",
            uuid.UUID(room_id),
            json.dumps({"id": scenario["id"], "title": scenario["title"],
                        "situation": scenario["situation"]}, ensure_ascii=False),
            room.time_limit_s)
        for uid, p in players.items():
            await db.pool.execute(
                "INSERT INTO battle_players (room_id, user_id, role, form_factor, secret_goal, rule_card)"
                " VALUES ($1,$2,$3,$4,$5,$6)",
                uuid.UUID(room_id), uuid.UUID(uid), p["role"], p["form_factor"],
                p["brief"]["secret"], None)
    return room


@router.websocket("/ws/room/{room_id}")
async def room_ws(ws: WebSocket, room_id: str, token: str):
    user_id = user_id_from_token(token)
    if user_id is None:
        await ws.close(code=4401)
        return
    room = rooms.get(room_id)
    if room is None or user_id not in room.players:
        await ws.close(code=4404)
        return
    await ws.accept()
    room.sockets[user_id] = ws
    try:
        while True:
            # receive_text()는 바이너리 프레임이 섞여 들어오면 KeyError로 죽으므로
            # 저수준 receive()로 받아 타입별로 직접 분기한다.
            raw = await ws.receive()
            if raw["type"] == "websocket.disconnect":
                raise WebSocketDisconnect(raw.get("code", 1000), raw.get("reason"))
            if raw.get("bytes") is not None:
                # 오디오 프레임(Phase 2) — 저장·가공 없이 즉시 상대에게 전달
                await room.relay_audio(user_id, raw["bytes"])
                continue
            msg = json.loads(raw["text"])
            match msg.get("type"):
                case "ready":  # 브리핑 준비 완료 → 양측 완료 시 통화 시작
                    room.ready.add(user_id)
                    if room.state == "matched":
                        await room.set_state("briefing")
                    if room.ready == set(room.players):
                        await room.start_call()
                case "utterance":  # B-lite: STT 텍스트 릴레이 → 상대가 TTS 재생
                    utt = {
                        "type": "utterance",
                        "from": user_id,
                        "role": room.players[user_id]["role"],  # 관전자용 (당사자는 from 사용)
                        "text": msg["text"],
                        "tStartMs": msg.get("tStartMs", room.t_ms()),
                    }
                    await room.broadcast(utt)
                    room.utterances.append({  # 최종 심판용 (role 표기)
                        "role": room.players[user_id]["role"],
                        "text": utt["text"],
                        "t_start_ms": utt["tStartMs"],
                    })
                    if db.pool:
                        await db.pool.execute(
                            "INSERT INTO utterances (room_id, speaker_user, speaker, text, t_start_ms)"
                            " VALUES ($1,$2,'user',$3,$4)",
                            uuid.UUID(room_id), uuid.UUID(user_id), utt["text"], utt["tStartMs"])
                    room.maybe_incremental()  # 발화 3개 누적 시 실시간 심판 (FSD §4.2)
                case "hang_up":
                    await room.end_call()
    except WebSocketDisconnect:
        room.sockets.pop(user_id, None)
        # TODO(P1): 15초 재접속 유예 → AI 이어받기/판 무효 (IA F3)


@router.get("/battles/live/latest")
async def latest_live_battle():
    """가장 최근 통화 중(in_call) 배틀 방 — 관전용(데모 프로젝터). 비밀 제외."""
    live = [r for r in rooms.values() if r.state == "in_call"]
    if not live:
        return {"roomId": None}
    room = max(live, key=lambda r: r.started_at or 0)
    return {
        "roomId": room.id,
        "players": {
            p["role"]: {"nickname": p["nickname"], "formFactor": p["form_factor"]}
            for p in room.players.values()
        },
    }


@router.websocket("/ws/watch/{room_id}")
async def watch_ws(ws: WebSocket, room_id: str, token: str):
    """읽기 전용 관전 — 비밀 목표·규칙 카드는 절대 전송하지 않는다(규칙 #2)."""
    if user_id_from_token(token) is None:
        await ws.close(code=4401)
        return
    room = rooms.get(room_id)
    if room is None:
        await ws.close(code=4404)
        return
    await ws.accept()
    room.spectators.append(ws)
    try:
        await ws.send_text(json.dumps(room.spectator_snapshot(), ensure_ascii=False))
        while True:
            await ws.receive_text()  # 관전자 입력은 무시 (연결 유지용)
    except WebSocketDisconnect:
        pass
    finally:
        if ws in room.spectators:
            room.spectators.remove(ws)
