"""데스크톱 STT용 faster-whisper WebSocket 서버.

프로토콜 (클라이언트 = Flutter DesktopSttEngine):
  클라 → 서버 : 16kHz mono PCM16 오디오 바이너리 프레임
                + 발화 종료 시 텍스트 프레임 {"event": "stop"} (버퍼 강제 flush)
  서버 → 클라 : {"text": str, "isFinal": true, "tStartMs": int}

발화 분절: webrtcvad로 30ms 프레임 판정, 무음 0.8초 누적 시 한 발화로 끊어
faster-whisper에 전사. tStartMs = 발화 시작(통화 시작=0) 상대 시각(ms).
"""

import asyncio
import json
import os

import numpy as np
import webrtcvad
import websockets
from faster_whisper import WhisperModel

SAMPLE_RATE = 16000
FRAME_MS = 30
FRAME_BYTES = SAMPLE_RATE * FRAME_MS // 1000 * 2  # 16-bit mono → 960 bytes
SILENCE_MS = 800
SILENCE_FRAMES = SILENCE_MS // FRAME_MS  # ≈ 26 프레임

# 무억제 마이크의 방 소음 바닥이 webrtcvad(2) 문턱보다 높아 VAD만으로는 침묵을
# 판정 못 한다 (2026-07-13 camp-3 실측: ±50 균일 노이즈도 87%가 speech 판정
# → silence 카운터가 영원히 26에 못 닿아 flush 불발). RMS 게이트를 앞단에 둔다.
RMS_GATE = float(os.getenv("WHISPER_RMS_GATE", "300"))
# 안전망: VAD가 포화돼도 무한 무응답만은 방지 — 누적 발화가 이 길이를 넘으면 강제 flush.
MAX_SEGMENT_MS = 10_000
MAX_SEGMENT_BYTES = SAMPLE_RATE * 2 * MAX_SEGMENT_MS // 1000

# 기본값 = 3090(GPU) + large-v3(한국어 정확도↑). 로컬 CPU: WHISPER_DEVICE=cpu WHISPER_COMPUTE=int8
MODEL = os.getenv("WHISPER_MODEL", "large-v3")
DEVICE = os.getenv("WHISPER_DEVICE", "cuda")
COMPUTE = os.getenv("WHISPER_COMPUTE", "int8_float16")  # large-v3를 ~1.8GB로(정확도 손실 미미)
model = WhisperModel(MODEL, device=DEVICE, compute_type=COMPUTE)
vad = webrtcvad.Vad(2)  # 0(관대)~3(엄격)


def frame_rms(frame: bytes) -> float:
    a = np.frombuffer(frame, dtype=np.int16).astype(np.float32)
    return float(np.sqrt(np.mean(a * a)))


def transcribe(pcm: bytes) -> str:
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    segments, _ = model.transcribe(
        audio, language="ko", beam_size=1,
        # 2차 관문(Silero): webrtcvad+RMS 게이트를 통과한 버퍼라도 소음뿐이면
        # 전사 없이 빈 결과 — 시끄러운 방에서 "감사합니다" 환청 방지 (2026-07-13).
        vad_filter=True,
        condition_on_previous_text=False,  # 환청이 다음 전사로 전염되는 것 방지
    )
    # no_speech_prob 높은 세그먼트 = whisper 스스로 말 아니라고 본 구간 — 버림.
    return "".join(s.text for s in segments if s.no_speech_prob < 0.6).strip()


async def handle(ws, *_):
    buf = bytearray()          # 프레임 경계 정렬용 미처리 바이트
    voiced = bytearray()       # 현재 발화의 음성 프레임 누적
    triggered = False          # 발화 진행 중 여부
    silence = 0                # 연속 무음 프레임 수
    frame_index = 0            # 연결 시작 이후 총 프레임 수
    seg_start_frame = 0        # 현재 발화 시작 프레임 인덱스
    loop = asyncio.get_event_loop()

    async def flush():
        nonlocal voiced, triggered, silence
        if not voiced:
            return
        pcm = bytes(voiced)
        voiced = bytearray()
        triggered = False
        silence = 0
        text = await loop.run_in_executor(None, transcribe, pcm)
        if text:
            await ws.send(json.dumps({
                "text": text,
                "isFinal": True,
                "tStartMs": seg_start_frame * FRAME_MS,
            }))

    async for message in ws:
        # 제어 프레임(텍스트): stop = 강제 flush, cancel = 현재 분절 폐기(전사 없음)
        if isinstance(message, str):
            try:
                event = json.loads(message).get("event")
                if event == "stop":
                    await flush()
                elif event == "cancel":  # 클라 에코 게이트 — TTS 직전 새어든 오디오 폐기
                    voiced = bytearray()
                    triggered = False
                    silence = 0
            except (ValueError, AttributeError):
                pass
            continue

        # 오디오 프레임(바이너리)
        buf.extend(message)
        while len(buf) >= FRAME_BYTES:
            frame = bytes(buf[:FRAME_BYTES])
            del buf[:FRAME_BYTES]
            frame_index += 1
            # RMS 게이트를 먼저 — 게이트 미달이면 VAD 문지도 않고 침묵 처리.
            is_speech = (frame_rms(frame) >= RMS_GATE
                         and vad.is_speech(frame, SAMPLE_RATE))

            if not triggered:
                if is_speech:
                    triggered = True
                    seg_start_frame = frame_index
                    voiced.extend(frame)
                    silence = 0
                # 선행 무음은 버림
            else:
                voiced.extend(frame)
                if is_speech:
                    silence = 0
                else:
                    silence += 1
                    if silence >= SILENCE_FRAMES:
                        await flush()
                if len(voiced) >= MAX_SEGMENT_BYTES:
                    await flush()


async def main():
    async with websockets.serve(handle, "0.0.0.0", 8765, max_size=None):
        print("Whisper WS server listening on ws://0.0.0.0:8765")
        await asyncio.Future()  # 영구 대기


if __name__ == "__main__":
    asyncio.run(main())
