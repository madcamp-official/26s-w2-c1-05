# 26s-w2-c1-05

## 공통과제 II : 협업형 실전 산출물 제작 (2인 1팀)

**목적:** 실시간 인터랙션, LLM Wrapper, Cross-Platform 중 하나의 옵션을 선택해 구현하며, 선택한 기술을 실제로 동작하는 형태의 산출물로 완성한다.

**선택 옵션:**

| 옵션 | 설명 |
|---|---|
| 실시간 인터랙션 | 사용자 간 상태 변화, 실시간 데이터 흐름, 스트리밍 응답 등 실시간성이 드러나는 기능을 구현 |
| LLM Wrapper | LLM API를 활용하여 AI 기능이 포함된 산출물을 구현 |
| Cross-Platform | 하나의 산출물을 여러 실행 환경에서 사용할 수 있도록 구현* |

> *데스크톱 앱 ↔ 모바일 앱; 혹은 다른 폼팩터에서의 앱; 웹만/웹 기반 프레임워크(Electron, Tauri 등) 대신 다른 프레임워크를 시도해보는 것을 적극 권장

**결과물:** 선택한 옵션이 적용된 작동 가능한 산출물, 실행 가능한 코드, 시연 자료 및 관련 문서

---

## 팀원

| 이름 | 학교 | GitHub | 역할 |
|---|---|---|---|
| 김희서 | 서울대 | grace0068 | 설계 및 디자인 위주 개발 |
| 주성민 | Kaist | iconflorinity | TTS 기능 위주 개발 |

---

## 선택 옵션

- [O] 실시간 인터랙션
- [O] LLM Wrapper
- [O] Cross-Platform

---

## 기획안

- **산출물 주제:** 콜포비아(전화 공포) 극복을 위한 실전 전화 트레이닝 게임 여보세요
- **제작 목적:** 전화 통화를 어려워하는 사용자가 AI 보스와의 가상 통화(싱글) 및 실제 유저와의
  실시간 협상 배틀(멀티)을 통해 게임처럼 반복 연습하며 실전 커뮤니케이션 능력을 기르게 한다.
- **선택 옵션:** 실시간 인터랙션 + LLM Wrapper + Cross-Platform (3옵션 모두 충족)
- **핵심 구현 요소:**
  - AI 보스 6종과의 실시간 음성 통화(STT→LLM 스트리밍→TTS) + 판정·피드백 리포트
  - 유저 간 실시간 1:1 협상 배틀(실시간 오디오 릴레이, 5필드 비밀 브리핑, 실시간 기세 게이지, LLM 판정)
  - Flutter 단일 코드베이스로 Android 앱 + Windows 데스크톱 앱 동시 지원(크로스 폼팩터 매칭 포함)
- **사용 / 시연 시나리오:**
  1. 온보딩(소셜/이메일 로그인) → 보스 도감에서 "치킨집 사장님"에게 전화 걸어 배달 주문 클리어 → 판정/리포트 확인
  2. 실전 배틀 매칭 → 상대와 비공개 목표·비밀을 각자 확인 → 실시간 통화로 협상 → 판정 + 서로의 비밀 공개
  3. (데모) 데스크톱에서 진행 중인 배틀을 관전 모드로 실시간 중계

### 개발 일정

| 날짜 | 목표 |
|---|---|
| Day 1 |  |
| Day 2 |  |
| Day 3 |  |
| Day 4 |  |
| Day 5 |  |
| Day 6 |  |
| Day 7 |  |

---

## 구현 명세서

| 구현 요소 | 설명 | 우선순위 |
|---|---|---|
| AI 대전(보스전) | 보스 6종과의 실시간 음성 통화, 감정 태그 기반 TTS, LLM 최종 심판+리포트 | 필수 |
| 실전 배틀 | 실시간 1:1 매칭, 실시간 오디오 릴레이, 5필드 비밀 브리핑, 인크리멘탈+최종 심판 | 필수 |
| 크로스 플랫폼 | Android + Windows 단일 코드베이스, 크로스 폼팩터 배틀 매칭 | 필수 |
| 계정/전적 | Google·Kakao·이메일 로그인, 도감 진행, 전적 목록/상세, 전적 대시보드 | 필수 |
| 관전 모드 | 진행 중인 배틀을 데스크톱에서 실시간 관전(데모용) | 선택 |
| Whisper 워치독 | GPU 경합으로 인한 STT 장애 자동 감지·복구 | 선택 |
| ELO 랭킹 | 배틀 승패 기반 랭킹 시스템 | 미구현(스키마만 존재) |

---

## 아키텍처

```
[Flutter 클라이언트 (Android / Windows)]
  ├─ 음성 캡처(record) ──WebSocket──▶ [게임 서버 /ws/stt] ──WebSocket(localhost)──▶ [faster-whisper]
  ├─ REST(JWT) ───────────────────▶ [게임 서버 FastAPI] ──▶ [PostgreSQL]
  ├─ WebSocket /ws/match, /ws/room, /ws/watch ─▶ [게임 서버 — 매칭 큐 · 배틀 방 상태머신]
  └─ TTS 요청 ─────────────────────▶ [게임 서버 /tts/synthesize] ──▶ [Qwen3-TTS(vLLM-Omni)] → 실패 시 [Google Cloud TTS] → 실패 시 클라 OS TTS

[게임 서버 /llm/chat] ──task별 분기──▶ [vLLM(Qwen3-14B-AWQ)]  (boss_turn, incremental)
                                  └─▶ [Gemini API]           (final_judge, scenario)

세 GPU 서비스(vLLM · Qwen3-TTS · faster-whisper)는 자체 GPU 서버(RTX 3090) 한 대에 상시 구동되며,
게임 서버는 Cloudflare Tunnel로 외부에 공개된다. whisper 전용 워치독이 GPU 경합으로 인한
CUDA 컨텍스트 손상을 감지해 자동 재시작한다.
```

자세한 기능/화면 구조는 [docs/FSD.md](docs/FSD.md), [docs/IA.md](docs/IA.md) 참고.

---

## 설계 문서

> 프로젝트 성격에 따라 필요한 항목만 작성

### 화면 / 인터페이스 설계

전체 사이트맵·라우트·화면별 콘텐츠 우선순위는 [docs/IA.md](docs/IA.md)에 정리. 디자인 시스템
토큰(색상/타이포/스페이싱)은 `mosimosi/lib/ui/theme.dart`, 재사용 컴포넌트는
`mosimosi/lib/ui/components.dart`에 정의.

### 데이터 구조

PostgreSQL, 스키마 원본은 `server/game/db/schema.sql`. 핵심 테이블:

| 테이블 | 역할 |
|---|---|
| `users` | 계정(소셜/이메일), 닉네임, elo(스텁) |
| `boss_progress` | 유저별 보스 격파 여부·최고점·도전 횟수 |
| `battle_rooms` | 배틀 방 상태머신·시나리오·최종 판정(verdict) |
| `battle_players` | 방 참가자별 비밀 목표·규칙 카드(행 단위 격리) |
| `sessions` | 싱글/배틀 공용 판 기록 (모드·결과·점수·판정 JSON) |
| `utterances` | 발화 로그 (통화 시작 기준 상대 시각 `t_start_ms`) |
| `llm_logs` | LLM 요청/응답 로그 (추후 데이터 활용 후보) |
| `judge_events` | 배틀 인크리멘탈 심판 이벤트(관전 리플레이·판정 시비 대응) |

보스 정의(페르소나 프롬프트·클리어 조건 등) 자체는 DB가 아니라 코드 시드
(`mosimosi/lib/core/data/bosses.dart`, `server/game/app/scenarios.py`)가 진실의 원천.

### API / 외부 서비스 연동

| Method / 방식 | Endpoint / 서비스 | 설명 | 비고 |
|---|---|---|---|
| GET/POST | `/auth/{provider}/start`, `/auth/{provider}/callback` | Google/Kakao OAuth (loopback) | JWT 발급 |
| POST | `/auth/local/signup`, `/auth/local/login` | 이메일+비밀번호 가입/로그인 | bcrypt |
| GET/PATCH/DELETE | `/users/me` | 내 계정 조회/닉네임 변경/탈퇴 | JWT 보호 |
| GET | `/users/me/progress`, `/users/me/sessions`, `/users/me/sessions/{id}`, `/users/me/battles` | 도감 진행·전적 | JWT 보호 |
| POST | `/sessions`, `/sessions/{id}/end` | 판 시작/종료 보고 | 도감 자동 갱신 |
| POST | `/llm/chat` | LLM 프록시 (SSE 스트리밍) | task별 vLLM/Gemini 분기 |
| POST | `/tts/synthesize` | TTS 프록시 | Qwen3-TTS → Google Cloud TTS 폴백 |
| WS | `/ws/stt` | 데스크톱/모바일 공통 STT 릴레이 | ↔ 로컬 faster-whisper |
| WS | `/ws/match` | 배틀 매칭 큐 | 성사 시 역할별 브리핑 전송 |
| WS | `/ws/room/{roomId}` | 배틀 방(오디오 릴레이+발화+상태) | ready/utterance/hang_up ↔ state/utterance/judge/verdict |
| WS | `/ws/watch/{roomId}` | 배틀 관전(읽기 전용) | 비밀 정보 포함(감독 시점) |
| 외부 | Google Gemini API | 최종 심판·시나리오 변수 생성 | |
| 외부 | Google Cloud TTS | TTS 폴백 | |
| 외부 | Google/Kakao OAuth | 소셜 로그인 | |

---

## 산출물 및 실행 방법

- **산출물 설명:** 실시간 전화 시뮬레이션으로 실전 커뮤니케이션(주문·예약·협상·항의·거절)을 연습하는
  크로스플랫폼(Android/Windows) 앱. LLM 기반 보스 페르소나·실전 배틀 상대와 실시간 음성 인식/합성
  (STT/TTS)으로 실제 전화 통화처럼 상호작용한다.
- **실행 환경:** Android 8.0+ 실기기(마이크 필요) 또는 Windows 10/11 데스크톱. 서버(자체 GPU 서버)가
  상시 구동 중이어야 실제 LLM/TTS/STT/전적 기능이 동작한다.
- **실행 방법:** 아래 "빌드된 배포 파일 실행" 또는 "소스에서 직접 실행" 중 택1.
- **시연 영상 / 이미지:** (추후 추가)

### 빌드된 배포 파일 실행
- **Android:** APK 설치 후 실행(출처 불명 앱 설치 허용 필요)
- **Windows:** 압축 해제 후 `mosimosi.exe` 실행 (폴더 전체가 필요 — exe 파일 하나만으로는 실행 불가)

### 소스에서 직접 실행

```bash
cd mosimosi
flutter pub get
flutter run -d <device-id>   # flutter devices 로 연결된 기기 확인
```

서버 없이 클라이언트 UI만 확인하려면 `--dart-define=USE_FAKE_LLM=true` 추가.

### 배포 파일 빌드 (개발자용)

```bash
# Android APK
flutter build apk --release
# 결과: build/app/outputs/flutter-apk/app-release.apk

# Windows 실행 파일
flutter build windows --release
# 결과: build/windows/x64/runner/Release/ (폴더 전체를 배포)
```

### 서버 실행 (개발자용)

```bash
cd server/game
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```
LLM(vLLM 또는 `LLM_FALLBACK=gemini`), TTS(Qwen3-TTS 또는 Google Cloud TTS 키), whisper STT 서버가
각각 별도 프로세스로 필요(`server/whisper/server.py`, `server/deploy/systemd/*.service` 참고).

### 기술 구성

| 분류 | 사용 기술 |
|---|---|
| 클라이언트 | Flutter(Dart) — Android + Windows, go_router, flutter_soloud, record |
| 실행 환경 | Android 8.0+, Windows 10/11 |
| 데이터 저장 | PostgreSQL (전적·도감 진행·LLM 로그), flutter_secure_storage(JWT) |
| 외부 API / 서비스 | Google Gemini API(심판/시나리오), Google Cloud TTS(폴백), Google/Kakao OAuth |
| 자체 서빙 | vLLM(Qwen3-14B-AWQ), Qwen3-TTS(vLLM-Omni), faster-whisper — 자체 GPU 서버 |
| 기타 | Cloudflare Tunnel(서버 공개), systemd(서비스 관리), whisper 자동 복구 워치독 |

---

## 회고 문서

> [KPT 방법론 참고](https://velog.io/@habwa/%EB%8B%A8%EA%B8%B0-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8-%ED%9A%8C%EA%B3%A0-KPT-%EB%B0%A9%EB%B2%95%EB%A1%A0)

### Keep — 잘 된 점, 다음에도 유지할 것

- 
-
-

### Problem — 아쉬웠던 점, 개선이 필요한 것

-
-
-

### Try — 다음번에 시도해볼 것

-
-
-

### 팀원별 소감

**김희서:**

> 

**주성민:**

> TTS 생성 모델을 다뤄보는 경험은 평생 잊지 못할 것 같아요! Qwen3 tts를 깔기 위해 삽질했던 과정이 정말 값졌습니다!

---

## 참고 자료

### 실시간 인터랙션

**WebSocket**
- https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API
- https://techblog.woowahan.com/5268/
- https://tech.kakao.com/posts/391
- https://daleseo.com/websocket/
- https://kakaoentertainment-tech.tistory.com/110

**Socket.IO**
- https://socket.io/docs/v4/
- https://inpa.tistory.com/entry/SOCKET-%F0%9F%93%9A-Namespace-Room-%EA%B8%B0%EB%8A%A5
- https://adjh54.tistory.com/549
- https://fred16157.github.io/node.js/nodejs-socketio-communication-room-and-namespace/

**SSE (Server-Sent Events)**
- https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
- https://developer.mozilla.org/ko/docs/Web/API/Server-sent_events/Using_server-sent_events
- https://api7.ai/ko/blog/what-is-sse

**TCP / UDP Socket**
- https://docs.python.org/3/library/socket.html
- https://inpa.tistory.com/entry/NW-%F0%9F%8C%90-%EC%95%84%EC%A7%81%EB%8F%84-%EB%AA%A8%ED%98%B8%ED%95%9C-TCP-UDP-%EA%B0%9C%EB%85%90-%E2%9D%93-%EC%89%BD%EA%B2%8C-%EC%9D%B4%ED%95%B4%ED%95%98%EC%9E%90

**gRPC Streaming**
- https://grpc.io/docs/what-is-grpc/core-concepts/
- https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B0-HTTP2-Protobuf-%EA%B7%B8%EB%A6%AC%EA%B3%A0-%EC%8A%A4%ED%8A%B8%EB%A6%AC%EB%B0%8D
- https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B02-Channel-Stub
- https://inspirit941.tistory.com/371
- https://devocean.sk.com/blog/techBoardDetail.do?ID=167433

**WebRTC**
- https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API
- https://webrtc.org/getting-started/overview
- https://web.dev/articles/webrtc-basics?hl=ko
- https://devocean.sk.com/blog/techBoardDetail.do?ID=164885
- https://beomkey-nkb.github.io/%EA%B0%9C%EB%85%90%EC%A0%95%EB%A6%AC/webRTC%EC%A0%95%EB%A6%AC/
- https://gh402.tistory.com/45
- https://on.com2us.com/tech/webrtc-coturn-turn-stun-server-setup-guide/

**QUIC / WebTransport**
- https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API
- https://datatracker.ietf.org/doc/html/rfc9000
- https://news.hada.io/topic?id=13888

#### KCLOUD VM / Cloudflare Tunnel 환경별 주의사항

| 환경 | 사용 가능(권장) 기술 | 포트/조건 | 주의할 기술 |
|---|---|---|---|
| **로컬 / 일반 VM** | HTTP/REST, WebSocket, Socket.IO, SSE, TCP Socket, gRPC Streaming, WebRTC, QUIC/WebTransport 등 대부분 가능 | 직접 포트 개방 가능. 예: 3000, 5000, 8000, 8080, 9000 등. 외부 공개 시 방화벽/보안그룹/공인 IP 설정 필요 | WebRTC는 STUN/TURN 필요 가능. QUIC/WebTransport는 HTTP/3 · UDP 지원 필요 |
| **KCLOUD VM (VPN 내부)** | HTTP/REST, WebSocket, Socket.IO, SSE, WebRTC 시그널링 | 접속 기기 VPN 필요. 기본 허용 포트: **22, 80, 443**. 개발 포트(3000, 8000, 8080 등)는 직접 접근 제한 가능 | TCP Socket은 포트 제한 있음. gRPC는 HTTP/2 설정 필요. WebRTC 미디어·UDP·QUIC/WebTransport 비권장 |
| **KCLOUD VM + Tunnel** | HTTP/REST, WebSocket, Socket.IO, SSE, WebRTC 시그널링 | VM의 `localhost:<port>`를 도메인에 연결. `localPort`는 **1024~65535**. 예: 3000, 8000, 8080 가능 | 순수 TCP Socket, UDP, WebRTC 미디어/DataChannel, QUIC/WebTransport 불가. gRPC 보장 어려움 |
| **외부 서비스 + 우리 도메인** | HTTP/REST, WebSocket, Socket.IO, SSE, WebRTC 시그널링 | Vercel/Netlify/Railway/Render/AWS/GCP 등에 배포 후 CNAME/A 레코드 연결. 보통 외부는 **443** 사용 | WebSocket/gRPC/TCP/UDP는 플랫폼 지원 여부 확인 필요. 서버리스 플랫폼은 장시간 연결 제한 가능 |
| **서버 없이 외부 SaaS 사용** | Supabase Realtime, Firebase, Pusher/Ably, LLM API Streaming | 직접 포트 관리 불필요. 각 서비스 SDK/API 사용 | 커스텀 TCP/UDP 서버 구현 불가. WebRTC는 STUN/TURN 필요할 수 있음 |

### LLM Wrapper

- https://github.com/teddylee777/openai-api-kr
- https://github.com/teddylee777/langchain-kr
- https://devocean.sk.com/blog/techBoardDetail.do?ID=167407
- https://mastra.ai/docs

### Cross-Platform

- https://flutter.dev/
- https://reactnative.dev/
- https://docs.expo.dev/
- https://kotlinlang.org/multiplatform/
