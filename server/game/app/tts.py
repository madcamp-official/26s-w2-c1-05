"""Google Cloud Text-to-Speech 프록시 (규칙 #4: API 키는 서버에만).

보스전 통화 전용 — 콜세션이 문장 단위로 만든 텍스트를 보스별 보이스 프리셋으로
합성해 오디오 바이트를 반환한다. llm.py와 동일한 "키 은닉 프록시" 패턴이나,
여기는 SSE 스트리밍이 아니라 문장 하나를 통째로 합성해 반환한다(콜세션의
문장 단위 TTS 큐와 맞물리는 구조 — mosimosi/lib/core/call/call_session.dart 참고).

우선 보이스: Chirp3 HD (무료 100만자/월, 비스트리밍 요청이라 SSML 제약 없음).
pitch는 Chirp3 HD가 지원하지 않는 파라미터라 Neural2 폴백 보이스에만 적용하고,
Chirp3 HD 보이스명일 때는 전송을 생략한다(REST API reference 확인 완료).

Chirp3 HD 전용 markup pause 태그([pause short]/[pause long])로 호흡감을 보강한다.
pause 태그는 `input.markup` 필드에서만 동작하고 `input.text`/`input.ssml`에서는
무시되며, markup과 ssml은 상호배타적이다(REST API reference 확인 완료) — 그래서
Chirp3 HD + ssml=False 조합일 때만 자동으로 markup 경로를 쓴다.
"""

import base64
import os
import re

import httpx
from fastapi import APIRouter, HTTPException, Response
from pydantic import BaseModel

router = APIRouter()

_SYNTHESIZE_URL = "https://texttospeech.googleapis.com/v1/text:synthesize"

_ELLIPSIS_RE = re.compile(r"\.{3,}|…")
_COMMA_RE = re.compile(r"[,、]")


def _to_pause_markup(text: str) -> str:
    """쉼표 뒤에 짧은 숨, 말줄임표 뒤에 긴 숨 태그를 삽입한다.
    실제 쉼의 길이는 Chirp3 HD가 문맥을 보고 알아서 정한다(태그는 위치만 지정)."""
    out = _ELLIPSIS_RE.sub(lambda m: m.group() + "[pause long]", text)
    out = _COMMA_RE.sub(lambda m: m.group() + "[pause short]", out)
    return out


class TtsRequest(BaseModel):
    text: str
    voice_name: str  # 예: "ko-KR-Chirp3-HD-Charon"
    language_code: str = "ko-KR"
    pace: float | None = None  # speakingRate 0.25~2.0 (1.0=기본 속도)
    pitch: float | None = None  # semitone -20~20. Chirp3 HD 보이스면 무시됨
    ssml: bool = False


def _build_input(req: TtsRequest) -> dict:
    if req.ssml:
        return {"ssml": req.text}
    if "Chirp3-HD" in req.voice_name:
        return {"markup": _to_pause_markup(req.text)}
    return {"text": req.text}


@router.post("/tts/synthesize")
async def synthesize(req: TtsRequest):
    key = os.getenv("GOOGLE_TTS_API_KEY", "")
    if not key:
        raise HTTPException(503, "GOOGLE_TTS_API_KEY not configured")
    if not req.text.strip():
        raise HTTPException(400, "text is empty")

    audio_config: dict = {"audioEncoding": "MP3"}
    if req.pace is not None:
        audio_config["speakingRate"] = req.pace
    if req.pitch is not None and "Chirp3-HD" not in req.voice_name:
        audio_config["pitch"] = req.pitch

    body = {
        "input": _build_input(req),
        "voice": {"languageCode": req.language_code, "name": req.voice_name},
        "audioConfig": audio_config,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            _SYNTHESIZE_URL,
            headers={"X-Goog-Api-Key": key},
            json=body,
        )
        r.raise_for_status()
    audio_b64 = r.json()["audioContent"]
    return Response(content=base64.b64decode(audio_b64), media_type="audio/mpeg")
