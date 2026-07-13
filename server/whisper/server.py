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

# 기본값 = 3090(GPU) + large-v3(한국어 정확도↑). 로컬 CPU: WHISPER_DEVICE=cpu WHISPER_COMPUTE=int8
MODEL = os.getenv("WHISPER_MODEL", "large-v3")
DEVICE = os.getenv("WHISPER_DEVICE", "cuda")
COMPUTE = os.getenv("WHISPER_COMPUTE", "int8_float16")  # large-v3를 ~1.8GB로(정확도 손실 미미)
model = WhisperModel(MODEL, device=DEVICE, compute_type=COMPUTE)
vad = webrtcvad.Vad(2)  # 0(관대)~3(엄격)


def transcribe(pcm: bytes) -> str:
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    segments, _ = model.transcribe(audio, language="ko", beam_size=1)
    return "".join(s.text for s in segments).strip()


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
        # 제어 프레임(텍스트): 발화 종료 → 즉시 flush
        if isinstance(message, str):
            try:
                if json.loads(message).get("event") == "stop":
                    await flush()
            except (ValueError, AttributeError):
                pass
            continue

        # 오디오 프레임(바이너리)
        buf.extend(message)
        while len(buf) >= FRAME_BYTES:
            frame = bytes(buf[:FRAME_BYTES])
            del buf[:FRAME_BYTES]
            frame_index += 1
            is_speech = vad.is_speech(frame, SAMPLE_RATE)

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


async def main():
    async with websockets.serve(handle, "0.0.0.0", 8765, max_size=None):
        print("Whisper WS server listening on ws://0.0.0.0:8765")
        await asyncio.Future()  # 영구 대기


if __name__ == "__main__":
    asyncio.run(main())
