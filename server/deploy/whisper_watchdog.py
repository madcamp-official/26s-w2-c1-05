"""faster-whisper STT 워치독 (외부 헬스체크 → 자동 재시작).

배경: whisper(server.py)는 GPU 메모리 경합으로 CUDA 컨텍스트가 한 번 손상되면
(`out of memory` → 이후 `invalid device ordinal`), 프로세스는 살아있지만 모든
전사 요청이 실패한다. websockets 라이브러리가 예외를 연결 단위로 삼켜 프로세스가
죽지 않으므로 systemd의 Restart=always가 트리거되지 않는다(감지 불가). 그래서
외부에서 주기적으로 실제 전사 경로를 태워보고, 손상이 감지되면 재시작한다.

이 워치독은 server.py를 건드리지 않는다(관심사 격리). 문제가 생기면 이 서비스만
끄면 원상복구된다.

판정 방식:
  1) whisper WS에 접속해 더미 오디오 1초 + {"event":"stop"}을 보내 transcribe를
     실제로 호출한다(GPU 경로를 태운다).
  2) transcribe가 CUDA 손상으로 raise하면 server.py가 연결을 닫는다 → 이후
     recv/ping이 예외를 던진다 → UNHEALTHY.
  3) 정상이면(전사 결과가 비어도) 연결이 유지된다 → ping이 왕복한다 → HEALTHY.
  * 무의미 오디오라 전사 결과는 대개 비지만, 그건 정상이다(ping 생존이 진짜 신호).

오탐(정상 whisper를 재시작) 방지: 연속 실패가 임계치 이상일 때만, 그리고 직전
재시작으로부터 쿨다운이 지났을 때만 재시작한다(재시작 루프 방지).
"""
import asyncio
import json
import os
import random
import struct
import subprocess
import sys
import time

import websockets

URL = os.getenv("WD_URL", "ws://localhost:8765")
SERVICE = os.getenv("WD_SERVICE", "yeoboseyo-whisper")
PROBE_INTERVAL = float(os.getenv("WD_PROBE_INTERVAL", "60"))       # 정상일 때 점검 주기(초)
FAIL_RETRY = float(os.getenv("WD_FAIL_RETRY", "20"))              # 실패 후 재점검까지(초)
FAIL_THRESHOLD = int(os.getenv("WD_FAIL_THRESHOLD", "3"))         # 연속 실패 몇 회에 재시작
RESTART_COOLDOWN = float(os.getenv("WD_RESTART_COOLDOWN", "300")) # 재시작 간 최소 간격(초)
POST_RESTART_GRACE = float(os.getenv("WD_POST_RESTART_GRACE", "90"))  # 재시작 후 모델 로드 대기(초)
OPEN_TIMEOUT = float(os.getenv("WD_OPEN_TIMEOUT", "10"))
# 정상(무의미 오디오→전사 결과 없음)이면 recv가 이 시간까지 기다린다. 크래시는
# 연결이 닫혀 recv가 즉시 예외를 던지므로(타임아웃과 무관) 짧게 잡아도 감지력은
# 그대로 — 이 값은 "정상일 때 얼마나 기다렸다 ping으로 넘어갈지"만 정한다.
RECV_TIMEOUT = float(os.getenv("WD_RECV_TIMEOUT", "5"))
PING_TIMEOUT = float(os.getenv("WD_PING_TIMEOUT", "10"))
SAMPLE_RATE = 16000


def log(msg: str) -> None:
    print(f"[whisper-watchdog] {msg}", flush=True)


def _make_dummy_pcm(seconds: float = 1.0) -> bytes:
    """RMS 게이트(server.py 기본 300)를 확실히 넘는 백색소음 1초.
    표준편차 ~1000이라 RMS도 ~1000 > 300 → VAD/RMS 게이트를 통과해 GPU 전사 경로를 탄다."""
    random.seed(0)
    out = bytearray()
    for _ in range(int(seconds * SAMPLE_RATE)):
        v = int(random.gauss(0, 1000))
        v = max(-32768, min(32767, v))  # int16 범위 클램프
        out += struct.pack("<h", v)
    return bytes(out)


_DUMMY_PCM = _make_dummy_pcm()


async def probe() -> bool:
    """True=healthy, False=unhealthy. 예외는 전부 unhealthy로 수렴."""
    try:
        async with websockets.connect(URL, open_timeout=OPEN_TIMEOUT) as ws:
            await ws.send(_DUMMY_PCM)
            await ws.send(json.dumps({"event": "stop"}))
            # 전사 결과가 오면 받되, 안 와도(무의미 오디오) 정상.
            try:
                await asyncio.wait_for(ws.recv(), timeout=RECV_TIMEOUT)
            except asyncio.TimeoutError:
                pass
            # 양성 생존 확인 — transcribe가 죽어 연결이 닫혔다면 여기서 예외.
            pong_waiter = await ws.ping()
            await asyncio.wait_for(pong_waiter, timeout=PING_TIMEOUT)
        return True
    except Exception as e:
        log(f"probe 실패: {type(e).__name__}: {e}")
        return False


def restart_service() -> None:
    log(f"'{SERVICE}' 재시작 시도 (CUDA 컨텍스트 손상 추정)")
    try:
        subprocess.run(
            ["systemctl", "restart", SERVICE],
            check=True, timeout=60,
            capture_output=True, text=True,
        )
        log(f"'{SERVICE}' 재시작 명령 성공")
    except subprocess.CalledProcessError as e:
        log(f"재시작 실패(exit {e.returncode}): {e.stderr.strip()}")
    except Exception as e:
        log(f"재시작 실패: {type(e).__name__}: {e}")


async def main() -> None:
    log(f"시작 — URL={URL} service={SERVICE} interval={PROBE_INTERVAL}s "
        f"threshold={FAIL_THRESHOLD} cooldown={RESTART_COOLDOWN}s")
    consecutive = 0
    last_restart = 0.0
    logged_first_ok = False
    while True:
        healthy = await probe()
        if healthy:
            if consecutive:
                log("복구됨 (healthy)")
            elif not logged_first_ok:
                log("최초 점검 통과 (healthy) — 워치독 정상 동작 중")
                logged_first_ok = True
            consecutive = 0
            await asyncio.sleep(PROBE_INTERVAL)
            continue

        consecutive += 1
        log(f"unhealthy (연속 {consecutive}/{FAIL_THRESHOLD})")
        now = time.monotonic()
        if consecutive >= FAIL_THRESHOLD:
            if now - last_restart < RESTART_COOLDOWN:
                log(f"쿨다운 중 — 재시작 보류 (마지막 재시작 {int(now - last_restart)}s 전)")
                await asyncio.sleep(FAIL_RETRY)
                continue
            restart_service()
            last_restart = time.monotonic()
            consecutive = 0
            log(f"재시작 후 {POST_RESTART_GRACE}s 대기(모델 로드)")
            await asyncio.sleep(POST_RESTART_GRACE)
        else:
            await asyncio.sleep(FAIL_RETRY)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
