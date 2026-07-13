"""asyncpg 풀. DATABASE_URL 없으면 pool=None — DB 필요한 API는 503,
WS 릴레이·LLM 프록시는 DB 없이도 동작(개발 편의)."""

import os

import asyncpg

pool: asyncpg.Pool | None = None


async def connect() -> None:
    global pool
    url = os.getenv("DATABASE_URL")
    if not url:
        print("[db] DATABASE_URL missing - DB features disabled")
        return
    pool = await asyncpg.create_pool(url, min_size=1, max_size=10)
    print("[db] connected")


async def disconnect() -> None:
    if pool:
        await pool.close()


def require_pool() -> asyncpg.Pool:
    from fastapi import HTTPException

    if pool is None:
        raise HTTPException(503, "DB not configured (DATABASE_URL)")
    return pool
