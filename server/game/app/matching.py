"""매칭 큐 (인메모리, FSD 3.2.1): 1:1 선착순 페어링, 크로스 폼팩터 허용.

클라 → /ws/match?token=&form_factor= 접속 → 큐 진입 (유저는 JWT에서 식별,
닉네임은 DB 조회 — 클라가 보낸 값을 신뢰하지 않는다).
2명 모이면 방 생성, 각자에게 자기 몫 브리핑만 전송(규칙 #2).
30초 폴백(AI 상담원)은 클라 타이머 — 서버는 큐 이탈만 처리.
"""

import asyncio
import json
import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from . import db
from .auth import user_id_from_token
from .rooms import create_room

router = APIRouter()

_queue: list[dict] = []
_lock = asyncio.Lock()


@router.websocket("/ws/match")
async def match_ws(ws: WebSocket, token: str, form_factor: str = "android"):
    user_id = user_id_from_token(token)
    if user_id is None:
        await ws.close(code=4401)
        return
    nickname = "익명"
    if db.pool:
        row = await db.pool.fetchrow("SELECT nickname FROM users WHERE id=$1", uuid.UUID(user_id))
        if row and row["nickname"]:
            nickname = row["nickname"]
    await ws.accept()
    me = {"user_id": user_id, "nickname": nickname, "form_factor": form_factor, "ws": ws}
    async with _lock:
        opponent = _queue.pop(0) if _queue else None
        if opponent is None:
            _queue.append(me)
    try:
        if opponent is not None:
            room = await create_room(
                {k: me[k] for k in ("user_id", "nickname", "form_factor")},
                {k: opponent[k] for k in ("user_id", "nickname", "form_factor")},
            )
            for side, other in ((me, opponent), (opponent, me)):
                p = room.players[side["user_id"]]
                await side["ws"].send_text(json.dumps({
                    "type": "matched",
                    "roomId": room.id,
                    "role": p["role"],
                    "secretGoal": p["secret_goal"],       # ★자기 몫만
                    "ruleCard": p["rule_card"],
                    "openingLine": p["opening_line"],
                    "situation": "온라인 쇼핑몰 「급배송」 환불 분쟁. 민원인이 3주째 환불을 요구하고 있습니다.",
                    "opponent": {"nickname": other["nickname"], "formFactor": other["form_factor"]},
                }, ensure_ascii=False))
        # 소켓 유지 (매칭 후엔 클라가 닫고 /ws/room으로 이동)
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        async with _lock:
            if me in _queue:
                _queue.remove(me)
