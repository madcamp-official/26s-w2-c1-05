# Whisper STT 서버 (데스크톱 스파이크용)

Flutter 데스크톱(`DesktopSttEngine`)이 마이크 PCM을 WebSocket으로 보내면
발화 단위로 잘라 faster-whisper로 전사해 텍스트를 돌려준다.

## 설치 (ML 서버 = RTX 3090, Linux 권장)

```bash
cd server/whisper
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

- 첫 실행 시 Whisper `small` 모델(~0.5GB)이 자동 다운로드됨
- 로컬 Windows CPU 테스트 시 `webrtcvad` 빌드 실패하면: `pip install webrtcvad-wheels`

## 실행

`device`/`compute_type` 은 환경변수로 조절 (기본값 = GPU):

```bash
# 3090 (GPU, 기본값)
python server.py

# 로컬 CPU 테스트
WHISPER_DEVICE=cpu WHISPER_COMPUTE=int8 python server.py
# → Whisper WS server listening on ws://0.0.0.0:8765
```

## 클라이언트에서 연결 (`mosimosi/.env` 의 `WHISPER_WS_URL`)

**권장 — SSH 터널** (방화벽/포트 개방 불필요, `.env` 그대로 `ws://localhost:8765`):
```bash
# 개발 PC(Windows)에서. 서버는 localhost:8765 로 리슨.
ssh -L 8765:localhost:8765 <user>@<3090-host>
# 터널 유지한 채 앱 실행 → 로컬 8765 가 서버 8765 로 연결됨
```

**대안 — 직접 접속** (서버가 같은 LAN이고 8765 인바운드 허용 시):
`.env` 를 `WHISPER_WS_URL=ws://<3090-IP>:8765` 로 변경.

## 프로토콜

| 방향 | 형식 |
|---|---|
| 클라 → 서버 | 16kHz mono PCM16 **바이너리** 프레임 |
| 클라 → 서버 | `{"event":"stop"}` **텍스트** 프레임 → 현재 버퍼 즉시 전사 |
| 서버 → 클라 | `{"text": str, "isFinal": true, "tStartMs": int}` |

## 분절 규칙

webrtcvad로 30ms 프레임을 음성/무음 판정, **무음 0.8초** 누적 시 한 발화로 끊어
전사한다. Push-to-talk 종료(`stop` 이벤트) 시에는 무음 대기 없이 즉시 flush.
`tStartMs` 는 연결 시작 기준 발화 시작 상대 시각(ms) — 채점 타임스탬프 규칙(FSD §5.3).
