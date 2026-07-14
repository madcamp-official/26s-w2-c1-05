"""여보세요 게임 서버 진입점.

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""

from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI

load_dotenv()

from . import api, auth, db, llm, matching, rooms, stt, tts  # noqa: E402


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    yield
    await db.disconnect()


app = FastAPI(title="여보세요 게임 서버", lifespan=lifespan)
app.include_router(auth.router)  # /users/me가 api의 /users/{user_id}보다 먼저 매칭돼야 함
app.include_router(api.router)
app.include_router(llm.router)
app.include_router(matching.router)
app.include_router(rooms.router)
app.include_router(stt.router)
app.include_router(tts.router)


@app.get("/health")
async def health():
    return {"ok": True, "db": db.pool is not None}
