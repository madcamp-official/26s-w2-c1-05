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


# ---- 배틀 전적 (배틀 로비 탭, 디자인 3a) ----
@router.get("/users/me/battles")
async def my_battles(user_id: uuid.UUID = Depends(current_user)):
    """최근 배틀 목록 + 집계(승패·연승·역할별 승률·elo). 종료된 방만."""
    pool = require_pool()
    rows = await pool.fetch(
        """SELECT r.ended_at, r.winner_user_id, r.final_momentum,
                  me.role AS my_role, uo.nickname AS opponent
           FROM battle_players me
           JOIN battle_rooms r ON r.id = me.room_id AND r.ended_at IS NOT NULL
           JOIN battle_players op ON op.room_id = me.room_id AND op.user_id <> me.user_id
           JOIN users uo ON uo.id = op.user_id
           WHERE me.user_id = $1
           ORDER BY r.ended_at DESC LIMIT 50""", user_id)
    elo_row = await pool.fetchrow("SELECT elo FROM users WHERE id=$1", user_id)

    recent = []
    wins = losses = draws = 0
    role_total: dict[str, int] = {"agent": 0, "claimant": 0}
    role_wins: dict[str, int] = {"agent": 0, "claimant": 0}
    streak = 0
    streak_open = True  # 최신부터 연속 승 집계
    for r in rows:
        if r["winner_user_id"] == user_id:
            result = "win"
        elif r["winner_user_id"] is None:
            result = "draw"
        else:
            result = "lose"
        # final_momentum은 승자 관점(0~100) — 내 관점으로 변환.
        fm = r["final_momentum"] if r["final_momentum"] is not None else 50
        my_momentum = fm if result == "win" else (50 if result == "draw" else 100 - fm)
        wins += result == "win"
        losses += result == "lose"
        draws += result == "draw"
        role_total[r["my_role"]] += 1
        role_wins[r["my_role"]] += result == "win"
        if streak_open and result == "win":
            streak += 1
        else:
            streak_open = False
        recent.append({
            "opponent": r["opponent"],
            "myRole": r["my_role"],
            "result": result,
            "myMomentum": my_momentum,
            "endedAt": r["ended_at"].isoformat(),
        })

    def rate(role: str) -> float | None:
        return role_wins[role] / role_total[role] if role_total[role] else None

    return {
        "elo": elo_row["elo"] if elo_row else 1500,
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "streak": streak,
        "agentWinRate": rate("agent"),
        "claimantWinRate": rate("claimant"),
        "recent": recent[:10],
    }


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
