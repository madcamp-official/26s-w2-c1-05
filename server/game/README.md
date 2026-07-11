# 여보세요 게임 서버 (FastAPI)

REST(유저·도감·전적) + WebSocket(매칭·배틀 방 릴레이) + LLM 프록시(키 은닉).
FSD §8 백엔드. ML 서버(3090: vLLM + faster-whisper)와 같은 호스트에 동거 가능.

## 실행

```bash
cd server/game
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env    # 값 채우기 (최소 GEMINI_API_KEY)

# PostgreSQL (docker 한 줄)
docker run -d --name yeoboseyo-db -e POSTGRES_USER=yeoboseyo -e POSTGRES_PASSWORD=yeoboseyo \
  -e POSTGRES_DB=yeoboseyo -p 5432:5432 postgres:16
psql postgresql://yeoboseyo:yeoboseyo@localhost:5432/yeoboseyo -f db/schema.sql

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 엔드포인트

| 종류 | 경로 | 설명 |
|---|---|---|
| REST | `POST /users` `GET /users/{id}` | 온보딩 닉네임, 프로필 |
| REST | `GET /users/{id}/progress` | 도감 진행 |
| REST | `POST /sessions` `POST /sessions/{id}/end` | 판 시작/종료(트랜스크립트·심판 저장) |
| SSE | `POST /llm/chat` | LLM 프록시 — task별 vLLM/Gemini 분기, `LLM_FALLBACK=gemini` 강제 전환 |
| WS | `/ws/match?user_id=` | 매칭 큐 → 방 생성 → 역할·비밀 배정(자기 몫만 전송) |
| WS | `/ws/room/{room_id}?user_id=` | B-lite 텍스트 릴레이 + 방 상태 브로드캐스트 |

## 절대 규칙 대응 (Instructions.md)

- **#2 비밀 격리**: `battle_players` 행 단위 — 매칭 응답에 본인 secret_goal/rule_card만 포함
- **#3 타임스탬프 채점**: 발화는 `{speaker, text, tStartMs}` 그대로 저장, 서버 수신 시각은 채점에 미사용
- **#4 키 은닉**: Gemini/vLLM 키·주소는 서버 env에만. 클라이언트는 `/llm/chat`만 호출
- **#5 음성 미저장**: 스키마에 오디오 컬럼 없음
