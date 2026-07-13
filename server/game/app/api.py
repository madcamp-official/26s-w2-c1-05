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
