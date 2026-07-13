"""소셜 로그인(Google·Kakao OAuth code flow) + JWT + 내 계정 API.

플랫폼 공통 loopback 플로우 (Android·Windows 동일):
  1) 앱이 127.0.0.1:{port} 리스너를 열고 브라우저로 GET /auth/{provider}/start?port= 오픈
  2) 서버가 프로바이더 인가 페이지로 302 (state = port를 담은 단기 서명 토큰)
  3) 콜백에서 code 교환 → (provider, provider_id)로 유저 upsert → JWT 발급
  4) http://127.0.0.1:{port}/callback?token=… 으로 302 → 앱 리스너가 수신
비밀번호 없음 — 이메일은 프로바이더가 준 값을 저장만 한다.
"""

import os
import re
import time
import urllib.parse
import uuid

import asyncpg
import bcrypt
import httpx
import jwt
from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from .db import require_pool

router = APIRouter()

JWT_TTL_S = 30 * 24 * 3600  # 30일 — 리프레시 토큰 없이 단순 유지


def _secret() -> str:
    s = os.getenv("JWT_SECRET")
    if not s:
        raise HTTPException(503, "auth not configured (JWT_SECRET)")
    return s


def _provider_conf(provider: str) -> dict:
    if provider == "google":
        conf = {
            "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
            "token_url": "https://oauth2.googleapis.com/token",
            "client_id": os.getenv("GOOGLE_CLIENT_ID"),
            "client_secret": os.getenv("GOOGLE_CLIENT_SECRET"),
            "scope": "openid email",
        }
    elif provider == "kakao":
        conf = {
            "auth_url": "https://kauth.kakao.com/oauth/authorize",
            "token_url": "https://kauth.kakao.com/oauth/token",
            "client_id": os.getenv("KAKAO_REST_API_KEY"),
            "client_secret": os.getenv("KAKAO_CLIENT_SECRET"),  # 콘솔에서 켰을 때만
            # 이메일 동의항목을 콘솔에 등록 안 했으면 KAKAO_SCOPE= (빈 값)으로
            "scope": os.getenv("KAKAO_SCOPE", "account_email"),
        }
    else:
        raise HTTPException(404, "unknown provider")
    if not conf["client_id"]:
        raise HTTPException(503, f"auth not configured ({provider} client id)")
    return conf


def _redirect_uri(provider: str) -> str:
    base = os.getenv("PUBLIC_BASE_URL", "https://graceheeseo.madcamp-kaist.org")
    return f"{base}/auth/{provider}/callback"


# ---- JWT ----
def create_token(user_id: str) -> str:
    return jwt.encode(
        {"sub": user_id, "exp": int(time.time()) + JWT_TTL_S}, _secret(), algorithm="HS256")


def user_id_from_token(token: str) -> str | None:
    """유효하면 user_id, 아니면 None — 예외를 못 던지는 WS 핸들러에서도 사용."""
    try:
        return jwt.decode(token, _secret(), algorithms=["HS256"])["sub"]
    except Exception:
        return None


async def current_user(authorization: str | None = Header(None)) -> uuid.UUID:
    """REST 보호 의존성 — `Authorization: Bearer {jwt}` → user_id."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing bearer token")
    uid = user_id_from_token(authorization[7:])
    if uid is None:
        raise HTTPException(401, "invalid or expired token")
    return uuid.UUID(uid)


# ---- OAuth 플로우 ----
@router.get("/auth/{provider}/start")
async def auth_start(provider: str, port: int):
    conf = _provider_conf(provider)
    state = jwt.encode(
        {"port": port, "provider": provider, "exp": int(time.time()) + 600},
        _secret(), algorithm="HS256")
    params = {
        "client_id": conf["client_id"],
        "redirect_uri": _redirect_uri(provider),
        "response_type": "code",
        "state": state,
    }
    if conf["scope"]:
        params["scope"] = conf["scope"]
    return RedirectResponse(f"{conf['auth_url']}?{urllib.parse.urlencode(params)}")


def _loopback(port: int, params: dict) -> RedirectResponse:
    return RedirectResponse(f"http://127.0.0.1:{port}/callback?{urllib.parse.urlencode(params)}")


@router.get("/auth/{provider}/callback")
async def auth_callback(provider: str, state: str,
                        code: str | None = None, error: str | None = None):
    try:
        st = jwt.decode(state, _secret(), algorithms=["HS256"])
        port = int(st["port"])
        if st.get("provider") != provider:
            raise ValueError
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(400, "bad state")
    if error or not code:
        return _loopback(port, {"error": error or "cancelled"})

    conf = _provider_conf(provider)
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": conf["client_id"],
        "redirect_uri": _redirect_uri(provider),
    }
    if conf["client_secret"]:
        data["client_secret"] = conf["client_secret"]
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(conf["token_url"], data=data)
            r.raise_for_status()
            tok = r.json()
            if provider == "google":
                # id_token은 구글 토큰 엔드포인트에서 TLS로 직접 받았으므로 서명 검증 생략
                claims = jwt.decode(tok["id_token"], options={"verify_signature": False})
                provider_id, email = claims["sub"], claims.get("email")
            else:  # kakao
                me = await client.get(
                    "https://kapi.kakao.com/v2/user/me",
                    headers={"Authorization": f"Bearer {tok['access_token']}"})
                me.raise_for_status()
                j = me.json()
                provider_id = str(j["id"])
                email = (j.get("kakao_account") or {}).get("email")
    except Exception:
        return _loopback(port, {"error": "provider_error"})

    pool = require_pool()
    row = await pool.fetchrow(
        "SELECT id, nickname FROM users WHERE provider=$1 AND provider_id=$2",
        provider, provider_id)
    is_new = row is None
    if is_new:
        row = await pool.fetchrow(
            "INSERT INTO users (provider, provider_id, email) VALUES ($1,$2,$3)"
            " RETURNING id, nickname", provider, provider_id, email)
    else:
        await pool.execute(
            "UPDATE users SET email=COALESCE($2, email), last_seen_at=now() WHERE id=$1",
            row["id"], email)
    params = {
        "token": create_token(str(row["id"])),
        "user_id": str(row["id"]),
        "is_new": "true" if is_new else "false",
    }
    if row["nickname"]:
        params["nickname"] = row["nickname"]
    return _loopback(port, params)


# ---- 일반(이메일+비밀번호) 가입/로그인 — provider='local', provider_id=이메일 ----
# 이메일 인증 메일·비밀번호 재설정은 의도적 생략 (SMTP 인프라 없음, 데모 범위).
class LocalAuth(BaseModel):
    email: str
    password: str


def _issue(row, is_new: bool) -> dict:
    """소셜 loopback 콜백과 같은 필드 구성 — 앱 AuthResult가 공유."""
    return {
        "token": create_token(str(row["id"])),
        "user_id": str(row["id"]),
        "is_new": is_new,
        "nickname": row["nickname"],
    }


@router.post("/auth/local/signup")
async def local_signup(body: LocalAuth):
    email = body.email.strip().lower()
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise HTTPException(422, "invalid email")
    if len(body.password) < 8:
        raise HTTPException(422, "password must be at least 8 chars")
    pool = require_pool()
    pw_hash = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    try:
        row = await pool.fetchrow(
            "INSERT INTO users (provider, provider_id, email, password_hash)"
            " VALUES ('local',$1,$2,$3) RETURNING id, nickname", email, email, pw_hash)
    except asyncpg.UniqueViolationError:
        raise HTTPException(409, "email taken")
    return _issue(row, True)


@router.post("/auth/local/login")
async def local_login(body: LocalAuth):
    email = body.email.strip().lower()
    pool = require_pool()
    row = await pool.fetchrow(
        "SELECT id, nickname, password_hash FROM users"
        " WHERE provider='local' AND provider_id=$1", email)
    if (row is None or not row["password_hash"]
            or not bcrypt.checkpw(body.password.encode(), row["password_hash"].encode())):
        raise HTTPException(401, "invalid email or password")
    await pool.execute("UPDATE users SET last_seen_at=now() WHERE id=$1", row["id"])
    return _issue(row, False)


# ---- 내 계정 ----
@router.get("/users/me")
async def get_me(user_id: uuid.UUID = Depends(current_user)):
    pool = require_pool()
    row = await pool.fetchrow(
        "SELECT id, nickname, email, provider, elo, created_at FROM users WHERE id=$1", user_id)
    if row is None:
        raise HTTPException(404)
    return dict(row) | {"id": str(row["id"])}


class UpdateMe(BaseModel):
    nickname: str


@router.patch("/users/me")
async def update_me(body: UpdateMe, user_id: uuid.UUID = Depends(current_user)):
    nickname = body.nickname.strip()
    if not (1 <= len(nickname) <= 12):
        raise HTTPException(422, "nickname must be 1-12 chars")
    pool = require_pool()
    try:
        row = await pool.fetchrow(
            "UPDATE users SET nickname=$2 WHERE id=$1 RETURNING id, nickname", user_id, nickname)
    except asyncpg.UniqueViolationError:
        raise HTTPException(409, "nickname taken")
    if row is None:
        raise HTTPException(404)
    return {"id": str(row["id"]), "nickname": row["nickname"]}


@router.delete("/users/me")
async def delete_me(user_id: uuid.UUID = Depends(current_user)):
    """회원 탈퇴 — 내 진행·기록 삭제, 배틀 상대에게 남는 기록은 익명화."""
    pool = require_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute("DELETE FROM boss_progress WHERE user_id=$1", user_id)
            await conn.execute(
                "DELETE FROM utterances WHERE session_id IN"
                " (SELECT id FROM sessions WHERE user_id=$1)", user_id)
            await conn.execute(
                "UPDATE utterances SET speaker_user=NULL WHERE speaker_user=$1", user_id)
            await conn.execute("DELETE FROM sessions WHERE user_id=$1", user_id)
            await conn.execute(
                "UPDATE battle_rooms SET winner_user_id=NULL WHERE winner_user_id=$1", user_id)
            await conn.execute("DELETE FROM battle_players WHERE user_id=$1", user_id)
            await conn.execute("DELETE FROM users WHERE id=$1", user_id)
    return {"ok": True}
