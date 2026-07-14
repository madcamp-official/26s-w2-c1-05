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

from . import db, llm
from .auth import user_id_from_token

router = APIRouter()

# 데모 시나리오 (P1: Gemini 시나리오 생성기로 교체 — FSD 6.3)
DEMO_SCENARIO = {
    "situation": "온라인 쇼핑몰 「급배송」 환불 분쟁. 민원인이 3주째 환불을 요구하고 있습니다.",
    "secrets": {
        "claimant": "통화 2분 안에 「전액 환불」 확답 받아내기",
        "agent": "환불 없이 만족도 3점 이상으로 통화를 종료하세요.",
    },
    "rule_card": "고객이 소비자원 신고를 언급하면 접수 의무가 발생합니다.",
    "opening_lines": {
        "claimant": "3주째 환불이 안 되고 있는데요, 오늘은 확답을 듣고 싶어요.",
        "agent": "안녕하세요, 고객센터입니다. 어떤 부분이 불편하셨는지 여쭤봐도 될까요?",
    },
}


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
    def __init__(self, room_id: str, players: dict[str, dict]):
        self.id = room_id
        self.state = "matched"
        self.players = players  # user_id -> {role, form_factor, nickname, secret_goal, rule_card}
        self.sockets: dict[str, WebSocket] = {}
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
        for ws in list(self.sockets.values()):
            try:
                await ws.send_text(json.dumps(msg, ensure_ascii=False))
            except Exception:
                pass

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
        agent = self.players[self._role_uid("agent")]
        claimant = self.players[self._role_uid("claimant")]
        log = "\n".join(
            f"({u['t_start_ms'] // 1000}s) {u['role']}: {u['text']}" for u in delta_utts) \
            or "(지난 20초간 아무도 발화하지 않음 — 침묵이 이어지고 있다)"
        fired = ", ".join(self._judge_events_fired[-5:]) or "없음"
        return f"""너는 전화 배틀 게임 '여보세요'의 실시간 심판이다. 방금 오간 발화만 보고 즉각 판정해 JSON만 출력해라.

[공통 상황] {DEMO_SCENARIO['situation']}
[agent(상담원) 비밀 목표] {agent['secret_goal']}
[agent 규칙 카드] {agent['rule_card']}
[claimant(민원인) 비밀 목표] {claimant['secret_goal']}
[현재 기세] agent {self.momentum_agent} : claimant {100 - self.momentum_agent}
[이미 발동된 이벤트] {fired}
[새 발화] (초 발화자: 내용)
{log}

규칙:
- momentumDelta: -15~15 정수, agent 관점(+는 agent 우세). 설득 우위를 가져간 쪽으로. 특기할 것 없으면 0.
- 침묵 턴(새 발화 없음)이면: 시간을 끌어 이득을 보는 쪽·대화를 회피하는 쪽에 -5~-2 수준의 페널티를 줘라 (버티기는 승리 전략이 아니다). 힌트로 침묵을 깰 첫마디를 제안해라.
- event: 이번 발화에서 결정적 순간이 있을 때만 6자 내외 한 문구("규칙 카드 발동!", "논리 클린히트!", "감정 폭발 페널티"). 이미 발동된 이벤트와 중복 금지. 없으면 null.
- hintAgent / hintClaimant: 각자에게 주는 한 줄 화술 코치. ★상대의 비밀 목표·규칙 카드 내용을 절대 누설하지 마라.
- caster: 관전자용 실황 중계 한 줄 (양쪽 비밀 미포함, 스포츠 캐스터 톤).

출력 JSON (다른 텍스트 금지):
{{"momentumDelta": 0, "event": null, "hintAgent": "…", "hintClaimant": "…", "caster": "…"}}"""

    # ---------------------------------------------------------------- 최종 심판
    def _role_uid(self, role: str) -> str | None:
        for uid, p in self.players.items():
            if p["role"] == role:
                return uid
        return None

    async def _judge(self) -> dict:
        """전체 트랜스크립트 정밀 심판 (FSD 4.4). LLM 출력은 role 키 →
        서버가 user_id 키 verdict로 변환(UUID를 LLM에 출력시키지 않는다)."""
        try:
            raw = await _run_judge_llm(self._judge_prompt())
            j = _extract_json(raw)
            winner = j.get("winner")
            winner_uid = self._role_uid(winner) if winner in ("agent", "claimant") else None
            momentum = j.get("momentum") or {}
            players_out = {}
            for uid, p in self.players.items():
                jp = (j.get("players") or {}).get(p["role"]) or {}
                players_out[uid] = {
                    "role": p["role"],
                    "nickname": p["nickname"],
                    "secretGoal": p["secret_goal"],  # 종료 후 공개 (페이오프)
                    "ruleCard": p["rule_card"],
                    "goalAchieved": jp.get("goalAchieved") is True,
                    "goalNote": jp.get("goalNote") or "",
                    "ruleNote": jp.get("ruleNote") or "",
                    "rubric": jp.get("rubric") or [],
                    "improvement": jp.get("improvement") or {},
                }
            kq = j.get("keyQuote") or {}
            return {
                "winnerUserId": winner_uid,
                "verdictLine": j.get("verdictLine") or "",
                "momentum": {
                    uid: int(momentum.get(p["role"], 50))
                    for uid, p in self.players.items()
                },
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
                "momentum": {uid: 50 for uid in self.players},
                "players": {
                    uid: {
                        "role": p["role"],
                        "nickname": p["nickname"],
                        "secretGoal": p["secret_goal"],
                        "ruleCard": p["rule_card"],
                        "goalAchieved": None,
                        "goalNote": "",
                        "ruleNote": "",
                        "rubric": [],
                        "improvement": {},
                    }
                    for uid, p in self.players.items()
                },
                "keyQuote": {},
            }

    def _judge_prompt(self) -> str:
        def mmss(ms: int) -> str:
            s = ms // 1000
            return f"{s // 60:02d}:{s % 60:02d}"

        agent = self.players[self._role_uid("agent")]
        claimant = self.players[self._role_uid("claimant")]
        log = "\n".join(
            f"({mmss(u['t_start_ms'])}) {u['role']}: {u['text']}" for u in self.utterances
        ) or "(발화 없음)"
        return f"""너는 전화 배틀 게임 '여보세요'의 최종 심판이다. 아래 통화를 평가해 JSON만 출력해라.

[공통 상황] {DEMO_SCENARIO['situation']}
[agent(상담원) 비밀 목표] {agent['secret_goal']}
[agent 규칙 카드] {agent['rule_card']}
[claimant(민원인) 비밀 목표] {claimant['secret_goal']}
[통화 중 실시간 심판이 포착한 이벤트] {", ".join(self._judge_events_fired) or "없음"}
[통화 기록] (mm:ss 발화자: 내용)
{log}

평가 규칙:
- 과정 점수로 판정해라 — 시간 끌기·버티기는 승리 전략이 아니다.
- [실시간 이벤트]는 통화 중 심판이 포착한 결정적 순간들이다 — 판정 근거로 활용하되, 최종 판단은 전체 통화 기록을 직접 보고 내려라.
- 각 플레이어의 비밀 목표 달성 여부(goalAchieved)를 실제 대사 근거로 판단하고, goalNote에 근거를 한 줄로.
- agent의 ruleNote에는 규칙 카드 발동·대응 여부를 한 줄로 (발동 안 했으면 "발동 없음").
- rubric은 역할에 맞는 항목 2~3개 (label, score 1~5, comment는 실제 대사 인용 포함).
- improvement는 각자 서툴렀던 순간 1개 (situation=실제 발화, better=이렇게 말했다면).
- momentum은 최종 기세 (두 값의 합 = 100).
- keyQuote는 판을 결정지은 실제 대사 1개.
- 발화가 매우 적으면 무승부(winner="draw")로 판정해라.

출력 JSON 스키마 (다른 텍스트 금지):
{{"winner": "agent"|"claimant"|"draw", "verdictLine": "한 줄 판정 근거",
 "momentum": {{"agent": 0-100, "claimant": 0-100}},
 "players": {{
   "agent": {{"goalAchieved": bool, "goalNote": "근거", "ruleNote": "규칙 대응",
             "rubric": [{{"label": "항목", "score": 1-5, "comment": "인용 포함"}}],
             "improvement": {{"situation": "실제 발화", "better": "이렇게 말했다면"}}}},
   "claimant": {{"goalAchieved": bool, "goalNote": "근거", "ruleNote": "",
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
    """매칭 성사 → 역할 랜덤 배정 + 비밀 자기 몫만 (규칙 #2)."""
    users = [a, b]
    random.shuffle(users)
    roles = ["claimant", "agent"]
    players = {}
    for user, role in zip(users, roles):
        players[user["user_id"]] = {
            **user,
            "role": role,
            "secret_goal": DEMO_SCENARIO["secrets"][role],
            "rule_card": DEMO_SCENARIO["rule_card"] if role == "agent" else None,
            "opening_line": DEMO_SCENARIO["opening_lines"][role],
        }
    room_id = str(uuid.uuid4())
    room = Room(room_id, players)
    rooms[room_id] = room
    if db.pool:
        await db.pool.execute(
            "INSERT INTO battle_rooms (id, state, scenario, time_limit_s) VALUES ($1,'matched',$2,$3)",
            uuid.UUID(room_id), json.dumps({"situation": DEMO_SCENARIO["situation"]}, ensure_ascii=False),
            room.time_limit_s)
        for uid, p in players.items():
            await db.pool.execute(
                "INSERT INTO battle_players (room_id, user_id, role, form_factor, secret_goal, rule_card)"
                " VALUES ($1,$2,$3,$4,$5,$6)",
                uuid.UUID(room_id), uuid.UUID(uid), p["role"], p["form_factor"],
                p["secret_goal"], p["rule_card"])
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
