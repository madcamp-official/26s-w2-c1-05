"""데스크톱 STT 릴레이 (FSD §5.1): 외부 데스크톱 ↔ 게임서버 ↔ localhost faster-whisper.

whisper(:8765)는 외부 비노출(localhost 전용, 보안). 게임서버(:8080, 터널로 외부 공개)에
이 릴레이를 두어, 클라가 wss://<도메인>/ws/stt 로 접속하면 여기서 localhost:8765로 중계한다.
(cloudflared는 WebSocket 통과 지원 → 별도 터널 설정 불필요)

프레임은 변환 없이 양방향 통과:
  클라 → whisper : 16kHz mono PCM16 바이너리 + {"event":"stop"} 텍스트
  whisper → 클라 : {"text","isFinal","tStartMs"} 텍스트
음성 원본은 저장하지 않고 통과만 한다(규칙 #5).
"""

import asyncio
import os

from fastapi import APIRouter, WebSocket
from websockets.asyncio.client import connect

router = APIRouter()

WHISPER_URL = os.getenv("WHISPER_LOCAL_URL", "ws://localhost:8765")


@router.websocket("/ws/stt")
async def stt_relay(ws: WebSocket):
    await ws.accept()
    try:
        whisper = await connect(WHISPER_URL, max_size=None)
    except Exception:
        await ws.close(code=1011)  # whisper 미가동 → 조용히 종료(클라는 폴백 처리)
        return

    async def client_to_whisper():
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                return
            if (b := msg.get("bytes")) is not None:
                await whisper.send(b)
            elif (t := msg.get("text")) is not None:
                await whisper.send(t)

    async def whisper_to_client():
        async for out in whisper:
            if isinstance(out, (bytes, bytearray)):
                await ws.send_bytes(out)
            else:
                await ws.send_text(out)

    tasks = [
        asyncio.create_task(client_to_whisper()),
        asyncio.create_task(whisper_to_client()),
    ]
    try:
        # 한쪽이 끊기면 릴레이 종료
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        for t in tasks:
            t.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)  # 취소 완료 + 예외 회수
        try:
            await whisper.close()
        except Exception:
            pass
