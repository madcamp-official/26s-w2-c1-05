"""보스전 TTS 프록시 (규칙 #4: API 키·내부 주소는 서버에만).

백엔드 우선순위: ① Qwen3-TTS(vLLM-Omni, QWEN_TTS_URL) → ② Google Cloud TTS
(GOOGLE_TTS_API_KEY, Chirp3 HD) → ③ 503(클라가 OS 내장 TTS로 폴백).
클라이언트 계약(/tts/synthesize {text, voice_name, pace, pitch})은 그대로 —
voice_name(Chirp3 보이스명)을 서버가 Qwen 화자/속도/감정지시로 매핑한다.
튜닝(_QWEN_VOICE_MAP 값 수정)은 이 파일만 바꾸고 게임 서버를 재시작하면
반영되며, 클라이언트 재빌드는 필요 없다.

Google 경로(폴백 안전망) 세부사항: pitch는 Chirp3 HD가 지원하지 않는
파라미터라 Neural2 폴백 보이스에만 적용. markup pause 태그([pause short]/
[pause long])로 호흡감을 보강하며, markup과 ssml은 상호배타적이라 Chirp3 HD +
ssml=False 조합일 때만 자동 적용.
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


# ---- Qwen3-TTS (vLLM-Omni) 우선 경로 ----
_QWEN_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
# Chirp3 보이스명 → Qwen 화자/속도/감정지시. 청취 테스트로 확정한 배정
# (uncle_fu=치킨집 사장님, vivian=치과 접수원, sohee=환불 상담원).
_QWEN_VOICE_MAP = {
    "ko-KR-Chirp3-HD-Charon": {
        "voice": "uncle_fu",
        "speed": 1.05,
        "seed": 42,
        "instructions": "50대 한국 남성, 저녁 피크타임에 바빠서 정신없다가도 손님한테는 확 밝아지는 목소리, 텐션 오르내림이 뚜렷한 사장님 말투",
    },
    "ko-KR-Chirp3-HD-Kore": {
        "voice": "vivian",
        "speed": 1.3,
        "seed": 42,
        "instructions": "40대 한국 여성, 사무적으로 말하다가 순간 짜증이 확 묻어나는, 감정 기복이 있는 빠른 말투, 발음이 뭉개질 정도로 빠름",
    },
    "ko-KR-Chirp3-HD-Aoede": {
        "voice": "sohee",
        "speed": 1.0,
        "seed": 42,
        "instructions": "30대 한국 여성, 처음엔 억지로 차분한 척하다가 점점 짜증이 새어나오는, 감정이 억눌렸다 터지는 말투",
    },
}


async def _synthesize_qwen(req: TtsRequest) -> bytes | None:
    """Qwen 경로 시도 — 미설정·장애·SSML 요청·매핑 없음이면 None(Google로 폴백)."""
    base = os.getenv("QWEN_TTS_URL", "")
    cfg = _QWEN_VOICE_MAP.get(req.voice_name)
    if not base or req.ssml or cfg is None:
        return None
    body = {
        "model": _QWEN_MODEL,
        "input": req.text,
        "voice": cfg["voice"],
        "speed": cfg["speed"],
        "seed": cfg["seed"],
        "instructions": cfg["instructions"],
        "language": "Korean",
        "response_format": "mp3",
    }
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            r = await client.post(f"{base}/v1/audio/speech", json=body)
            r.raise_for_status()
            return r.content
    except Exception as e:
        print(f"[tts] Qwen synthesis failed for voice_name={req.voice_name}, "
              f"falling back to Chirp3 HD: {e}")
        return None


def _build_input(req: TtsRequest) -> dict:
    if req.ssml:
        return {"ssml": req.text}
    if "Chirp3-HD" in req.voice_name:
        return {"markup": _to_pause_markup(req.text)}
    return {"text": req.text}


@router.post("/tts/synthesize")
async def synthesize(req: TtsRequest):
    if not req.text.strip():
        raise HTTPException(400, "text is empty")

    qwen_audio = await _synthesize_qwen(req)
    if qwen_audio is not None:
        return Response(content=qwen_audio, media_type="audio/mpeg")

    key = os.getenv("GOOGLE_TTS_API_KEY", "")
    if not key:
        raise HTTPException(503, "no TTS backend available")

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
