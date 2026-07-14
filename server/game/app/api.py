"""REST: 유저 조회 · 도감 진행 · 판 기록 (FSD §8).

계정 생성·수정은 auth.py(소셜 로그인)로 이동. 여기 라우트는 모두
current_user(JWT)로 보호되며, '내 것'은 /users/me/* 경로를 쓴다.
"""

import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .auth import current_user
from .db import require_pool

router = APIRouter()


# ---- 유저 ----
@router.get("/users/{user_id}")
async def get_user(user_id: uuid.UUID):
    pool = require_pool()
    row = await pool.fetchrow("SELECT id, nickname, elo, created_at FROM users WHERE id=$1", user_id)
    if row is None:
        raise HTTPException(404)
    return dict(row) | {"id": str(row["id"])}


# ---- 도감 진행 ----
@router.get("/users/me/progress")
async def get_progress(user_id: uuid.UUID = Depends(current_user)):
    pool = require_pool()
    rows = await pool.fetch(
        "SELECT boss_id, cleared_at, best_score, attempts FROM boss_progress WHERE user_id=$1", user_id)
    return [dict(r) for r in rows]


# ---- 판 기록 ----
class StartSession(BaseModel):
    mode: str  # 'boss' | 'battle'
    boss_id: str | None = None
    room_id: uuid.UUID | None = None
    scenario_variables: list[str] | None = None


@router.post("/sessions")
async def start_session(body: StartSession, user_id: uuid.UUID = Depends(current_user)):
    pool = require_pool()
    row = await pool.fetchrow(
        "INSERT INTO sessions (user_id, mode, boss_id, room_id, scenario_variables, started_at)"
        " VALUES ($1,$2,$3,$4,$5,now()) RETURNING id",
        user_id, body.mode, body.boss_id, body.room_id,
        json.dumps(body.scenario_variables or [], ensure_ascii=False))
    return {"id": str(row["id"])}


class Utterance(BaseModel):
    speaker: str  # 'user' | 'boss'
    text: str
    t_start_ms: int


class EndSession(BaseModel):
    end_reason: str
    result: str
    score: int | None = None
    judge: dict | None = None
    transcript: list[Utterance] = []


@router.post("/sessions/{session_id}/end")
async def end_session(session_id: uuid.UUID, body: EndSession,
                      user_id: uuid.UUID = Depends(current_user)):
    pool = require_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            row = await conn.fetchrow(
                "UPDATE sessions SET ended_at=now(), end_reason=$2, result=$3, score=$4, judge=$5"
                " WHERE id=$1 RETURNING user_id, mode, boss_id",
                session_id, body.end_reason, body.result, body.score,
                json.dumps(body.judge, ensure_ascii=False) if body.judge else None)
            if row is None:
                raise HTTPException(404)
            if row["user_id"] != user_id:  # 남의 세션 종료 시도 — 트랜잭션 롤백
                raise HTTPException(403)
            for u in body.transcript:
                await conn.execute(
                    "INSERT INTO utterances (session_id, speaker, text, t_start_ms) VALUES ($1,$2,$3,$4)",
                    session_id, u.speaker, u.text, u.t_start_ms)
            # 도감 진행 갱신 (싱글 승리 시 격파·최고점)
            if row["mode"] == "boss" and row["boss_id"]:
                await conn.execute(
                    """INSERT INTO boss_progress (user_id, boss_id, attempts, best_score, cleared_at)
                       VALUES ($1, $2, 1, $3, CASE WHEN $4 THEN now() END)
                       ON CONFLICT (user_id, boss_id) DO UPDATE SET
                         attempts = boss_progress.attempts + 1,
                         best_score = GREATEST(COALESCE(boss_progress.best_score, 0), COALESCE($3, 0)),
                         cleared_at = COALESCE(boss_progress.cleared_at, CASE WHEN $4 THEN now() END)""",
                    row["user_id"], row["boss_id"], body.score, body.result == "win")
    return {"ok": True}


@router.get("/users/me/sessions")
async def list_sessions(limit: int = 20, user_id: uuid.UUID = Depends(current_user)):
    pool = require_pool()
    rows = await pool.fetch(
        "SELECT id, mode, boss_id, room_id, started_at, ended_at, result, score"
        " FROM sessions WHERE user_id=$1 ORDER BY started_at DESC LIMIT $2", user_id, limit)
    return [dict(r) | {"id": str(r["id"])} for r in rows]


@router.get("/users/me/sessions/{session_id}")
async def get_session_detail(session_id: uuid.UUID, user_id: uuid.UUID = Depends(current_user)):
    """전적 상세 — WHERE절에 user_id를 같이 걸어 남의 세션이면 존재 여부조차
    구분 안 되는 404로 통일(소유자 아님과 없음을 구분하는 403 응답은 방어벽 우회
    단서가 될 수 있어 지양). judge는 jsonb라 asyncpg가 원문 텍스트로 반환 —
    json.loads 안 하면 클라에 문자열로 이중 인코딩되어 내려간다."""
    pool = require_pool()
    row = await pool.fetchrow(
        "SELECT id, mode, boss_id, room_id, started_at, ended_at, end_reason, result, score, judge"
        " FROM sessions WHERE id=$1 AND user_id=$2", session_id, user_id)
    if row is None:
        raise HTTPException(404)
    # 배틀 발화는 session_id가 아니라 room_id로 저장됨(규칙 #2 격리 설계) — 지금은
    # 배틀 판이 sessions에 기록되지 않아 실질적으로 mode='boss'만 해당하지만,
    # 향후를 대비해 room_id 쪽도 대비해 조회한다.
    utterances = await pool.fetch(
        "SELECT speaker, COALESCE(refined_text, text) AS text, t_start_ms FROM utterances"
        " WHERE session_id=$1 OR room_id=$2 ORDER BY t_start_ms",
        session_id, row["room_id"])
    return dict(row) | {
        "id": str(row["id"]),
        "room_id": str(row["room_id"]) if row["room_id"] else None,
        "judge": json.loads(row["judge"]) if row["judge"] else None,
        "transcript": [dict(u) for u in utterances],
    }
