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

from . import db

router = APIRouter()

# 데모 시나리오 (P1: Gemini 시나리오 생성기로 교체 — FSD 6.3)
DEMO_SCENARIO = {
    "situation": "온라인 쇼핑몰 「급배송」 환불 분쟁. 민원인이 3주째 환불을 요구하고 있습니다.",
    "secrets": {
        "claimant": "통화 2분 안에 「전액 환불」 확답 받아내기",
        "agent": "환불 없이 만족도 3점 이상으로 통화를 종료하세요.",
    },
    "rule_card": "고객이 소비자원 신고를 언급하면 접수 의무가 발생합니다.",
}


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

    def t_ms(self) -> int:
        return 0 if self.started_at is None else int((time.monotonic() - self.started_at) * 1000)

    async def broadcast(self, msg: dict) -> None:
        for ws in list(self.sockets.values()):
            try:
                await ws.send_text(json.dumps(msg, ensure_ascii=False))
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

    async def _time_limit(self) -> None:
        await asyncio.sleep(self.time_limit_s)
        if self.state == "in_call":
            await self.end_call()

    async def end_call(self) -> None:
        if self._timer:
            self._timer.cancel()
        await self.set_state("judging")
        # TODO(P1): 최종 심판 호출 → verdict/winner 기록 → done 브로드캐스트
        await self.set_state("done")


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
async def room_ws(ws: WebSocket, room_id: str, user_id: str):
    room = rooms.get(room_id)
    if room is None or user_id not in room.players:
        await ws.close(code=4404)
        return
    await ws.accept()
    room.sockets[user_id] = ws
    try:
        while True:
            msg = json.loads(await ws.receive_text())
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
                    if db.pool:
                        await db.pool.execute(
                            "INSERT INTO utterances (room_id, speaker_user, speaker, text, t_start_ms)"
                            " VALUES ($1,$2,'user',$3,$4)",
                            uuid.UUID(room_id), uuid.UUID(user_id), utt["text"], utt["tStartMs"])
                    # TODO(P1): 발화 3~4개 누적 or 20초 경과 시 인크리멘탈 심판 트리거 (FSD §4.2)
                case "hang_up":
                    await room.end_call()
    except WebSocketDisconnect:
        room.sockets.pop(user_id, None)
        # TODO(P1): 15초 재접속 유예 → AI 이어받기/판 무효 (IA F3)
