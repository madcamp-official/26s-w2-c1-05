# 여보세요 — 콜포비아 실전 트레이닝 게임 기능 명세서

> 이 문서는 실제 구현된 코드(`mosimosi/`, `server/`)를 기준으로 작성됨. 아직 구현되지 않았거나
> 스텁 상태인 항목은 각 절에 "미구현"으로 명시함.

---

## 1. 프로젝트 개요

### 1.1 한 줄 정의
전화 공포(콜포비아)를 겪는 MZ세대가 "훈련"이 아니라 "게임"으로 전화 실력을 키우는 크로스 플랫폼
(Android + Windows) 앱. AI 보스와의 전화 보스전(싱글, "AI 대전")과 유저 간 실시간 전화 협상 배틀
(멀티, "실전 배틀")을 코어 루프로 하며, 통화 중 실시간 게임 연출(인내심/기세 게이지·이벤트 팝업·
AI 코치 귓속말)과 판 종료 후 LLM 판정·피드백 리포트를 제공한다.

### 1.2 과제 요건 충족
| 요건 | 충족 방식 |
|---|---|
| LLM 활용 | 보스 페르소나 대화, 인크리멘탈/최종 심판, 피드백 리포트, 시나리오 변수 생성 |
| 실시간 요소 | 음성 스트리밍 대화(STT/TTS), 실시간 매칭 큐(WebSocket), 실통화 오디오 릴레이, 실시간 기세 게이지 |
| 다중 사용자 | 실전 배틀(1:1 매칭, 크로스 폼팩터), 관전(watch) 모드 |
| 크로스 플랫폼 | Flutter 단일 코드베이스 → Android 앱 + Windows 데스크톱 앱, 두 폼팩터 간 매칭·대전 |

---

## 2. 플랫폼 구성

- **프레임워크**: Flutter 단일 코드베이스(Dart). 타겟은 Android + Windows 데스크톱뿐(iOS·웹 없음).
- **두 폼팩터는 동등한 완전 게임 클라이언트**: 데스크톱도 AI 대전·배틀·전적을 전부 수행. 레이아웃만
  `isDesktop(context)` 분기로 다르고 기능 삭제는 없음(`mosimosi/lib/ui/breakpoints.dart`).
- **크로스 폼팩터 매칭**: 배틀 매칭 시 `form_factor`('android'/'windows')를 서버에 함께 보내고,
  매칭 성사 시 상대 폼팩터를 상대 카드에 표시(`battle_matching_screen.dart`). 매칭 자체는 폼팩터
  구분 없이 선착순.
- **네비게이션**: 모바일 하단 탭바 / 데스크톱 좌측 `NavigationRail` — 홈·도감·배틀·전적 4탭
  (`main_shell.dart`). 통화·배틀 진행·설정·온보딩은 셸 밖 풀스크린 라우트.

---

## 3. 코어 게임 모드

### 3.1 싱글플레이 — 보스전 "AI 대전" / "진상 도감"

#### 3.1.1 보스 도감 (실제 6종, `mosimosi/lib/core/data/bosses.dart`)
| No. | id | 이름 | 시나리오 | 보이스(Qwen 화자) |
|---|---|---|---|---|
| 1 | chicken | 치킨집 사장님 | 배달 주문(메뉴·주소 전달) | uncle_fu |
| 2 | dental | 치과 접수원 | 진료 예약(고정 시간표 안에서 확정) | vivian |
| 3 | alba | 사장님(알바) | 시급 인상 협상(회피 돌파) | dylan |
| 4 | prof_grade | 교수님(성적) | 성적 이의제기 → 출결 정정 약속 받기 | uncle_fu |
| 5 | prof_gradschool | 교수님(대학원) | 대학원 영입 제안 정중히 거절 | aiden |
| 6 | refund | 고객센터 상담원 | 환불 거절 반박(법적 근거로 설득) | sohee |

- 각 보스는 `Boss` 모델(`core/models/boss.dart`)로 정의: `personaPrompt`(성격·말투·고정 오프닝·
  감정 지도·few-shot 1개), `clearConditions`, `timeLimit`(전부 3분), `DifficultyParams`(문장 길이·
  협조성·돌발빈도·말끊기 — 시스템 프롬프트에 텍스트로 렌더링), `TtsVoicePreset`, 선택적 `introStory`
  (메신저 대화 연출 후 발신 — `chicken`/`dental`/`alba`/`prof_grade`/`prof_gradschool`/`refund` 전부 있음).
- **잠금/해금 시스템은 없다** — `boss_list_screen.dart`의 6개 항목 모두 `locked: false`로 항상
  플레이 가능. 도감 화면은 서버 `GET /users/me/progress` 실데이터로 격파 여부·최고점만 표시.
- **8종 계획은 폐기**되고 실제로는 6종만 존재(예전 기획의 "미용실 원장/김 과장/보험 설계사"는
  구현되지 않고 alba/prof_grade/prof_gradschool로 교체됨).

#### 3.1.2 통화 플로우 (`boss_call_screen.dart` + `core/call/call_session.dart`)
1. 브리핑(`boss_briefing_screen.dart`) → (있으면) 인트로 스토리(`boss_intro_screen.dart`) → 발신
2. 신호음(ringback) 동안 LLM으로 랜덤 상황 변수 2~3개 생성(`generateScenarioVariables`, 실패 시
   변수 없이 진행) → 보스가 먼저 응대(고정 오프닝 대사)
3. **오픈마이크(기본)**: 통화 시작 시 STT 1회 `start()`, 서버(whisper) VAD가 0.8초 침묵마다 발화를
   끊어 순차로 결과를 보내주면 그대로 LLM에 전송. **PTT(설정에서 전환 가능)**: 눌러서 말하기.
4. LLM 응답은 스트리밍 수신 → 문장 단위로 끊어 TTS 큐에 순차 투입(첫 문장 완성 즉시 재생 시작)
5. 종료 사유 4종: `hangUp`(직접 끊기) / `timeOut`(3분 초과) / `silenceOverflow`(침묵 누적으로
   인내심 게이지 0) / `bossHangUp`(보스가 `[끝]` 태그로 스스로 마무리)
6. 종료 후 `boss_result_screen.dart`가 최종 심판(Gemini, `runFinalJudge`)을 호출 → 결과+리포트 표시
   → best-effort로 `POST /sessions/{id}/end` 보고(서버가 `boss_progress` 격파·최고점 자동 갱신)

#### 3.1.3 보스 응답 프로토콜 (LLM 출력 형식)
모든 보스 프롬프트는 공통 규칙(`bossCommonRules`, `core/models/boss.dart`)을 강제 적용:
- **감정 태그**: 매 응답 맨 앞에 `[평온]/[상냥]/[짜증]/[분노]/[미안]/[당황]` 중 하나 — 클라이언트
  `_consumeEmotionTag()`가 파싱해 자막·TTS에서 제거하고 TTS 감정 지시로 전달
- **종료 태그**: 통화를 스스로 마무리할 때 감정 태그 뒤 `[끝]` 부착 → 그 대사 TTS 재생 완료 후 보스가
  통화를 끊음(`_bossHangUpPending` → `_endAfterTtsDrained()`)
- 역할 고정·한글 전용·전화 상황 이탈 금지·인신공격 금지 등 안전/형식 규칙
- 최근 8발화만 히스토리로 유지 + 매 요청 끝에 "너는 {보스명}이다" 역할 재확인 앵커 문구 추가
  (턴이 쌓일수록 역할 드리프트가 생기는 문제의 완화책)

#### 3.1.4 인내심 게이지
통화 중 로컬 휴리스틱으로만 동작(서버 심판과 무관): 내 차례에 6초 이상 침묵하면 0.5초마다 2%씩
감소, 0이 되면 `silenceOverflow`로 자동 종료. **실시간 LLM 기반 게이지는 배틀 모드에만 존재**
(아래 §4) — 싱글엔 없음.

### 3.2 멀티플레이 — 실시간 "실전 배틀"

#### 3.2.1 매칭 (`server/game/app/matching.py`, `battle_matching_screen.dart`)
- `/ws/match?token=&form_factor=` 접속 → 인메모리 큐에서 1:1 선착순 페어링(크로스 폼팩터 허용)
- 성사 시 서버가 시나리오를 랜덤 선택(`scenarios.pick()`)하고 역할(`agent`/`claimant`)을 랜덤
  배정, 각자에게 **자기 몫 브리핑만** 전송(비밀 정보 격리 원칙)
- 30초 미매칭 시 클라이언트가 "AI와 배틀하기" 옵션을 보여주지만 **버튼은 스낵바로 "준비 중" 안내만
  하고 실제 AI 상담원 폴백은 미구현**. "계속 기다리기"로 큐 유지 가능.

#### 3.2.2 시나리오 3종 + 5필드 비밀 브리핑 (`server/game/app/scenarios.py`)
| id | 제목 | 상황 | 판정 방식 |
|---|---|---|---|
| exam_night | 시험 전날의 전화 | 공부 vs 마지막 모임 초대 | 범주형(`no_meet`/`short_meet`/`long_meet`) |
| used_deal | 스위치 28만원 | 중고거래 가격 협상 | 수치형(합의 금액, floor/cap + 조건부 완화) |
| deposit | 보증금 정산 | 집주인 vs 세입자 수리비 공제 | 수치형(공제액, floor/cap + 조건부 완화) |

각 역할 브리핑은 5필드: `personal`(상황) · `goal`(목표) · `winNote`(승패 기준) · `hardLine`(물러설
수 없는 선) + `exceptions`(조건부 예외) · `secret`(들키면 안 되는 비밀). 추가로 `chip`(통화 칩 — 목표/
선/비밀 한 줄 요약)과 `openingLine`(침묵 지속 시 제안할 첫마디), `rule`(서버가 최종 판정에 쓰는
코드 규칙)을 포함.

#### 3.2.3 판정 시스템 — LLM 사실 추출 + 서버 규칙 판정 분리
- **인크리멘탈 심판**(vLLM, `_incremental_judge`): 발화 3개 누적 또는 20초 경과마다 호출, 델타
  대화만 보고 기세(`momentumDelta`, agent 관점 ±15 clamp, 전체 5~95% 범위) + 이벤트 문구 + 개인별
  코치 힌트(상대에게 비밀 안 새게) + 관전 캐스터 코멘트를 JSON으로 반환. 침묵 턴에도 페널티 부여
  ("버티기 전략 실시간 처벌").
- **최종 심판**(Gemini, `_judge`): 전체 트랜스크립트에서 `settlement`(거래 성사 여부·합의 금액/
  결과 범주·충족 조건 목록)를 **추출만** 하고, "물러설 수 없는 선"을 넘었는지 여부는 서버 파이썬
  코드(`scenarios.decide_winner`/`crossed_line`)가 결정론적으로 판정 — LLM의 산술/기준 판단
  신뢰성에 기대지 않는 구조. 선을 넘긴 쪽이 있으면 자동 패배, 둘 다 무사하면 goalScore(LLM이
  채점) 차이로, 8점 미만 차이는 무승부.
- 심판 실패(LLM 장애 등) 시 무승부 폴백 — `done` 상태는 반드시 도달하도록 보장.

#### 3.2.4 통신 구조 — 실제로는 B-lite(텍스트)가 아니라 **실시간 오디오 릴레이**
- `/ws/room/{roomId}` 단일 WebSocket으로 세 종류 프레임을 다룸: 바이너리(내 마이크 PCM → 서버가
  즉시 상대에게 pass-through, 저장·가공 없음), `utterance`(STT 확정 텍스트 — 자막·심판용, TTS 재생
  아님), `ready`/`hang_up`(상태 전환)
- 즉 상대의 목소리는 실제 오디오로 들리고(`PcmStreamPlayer`), 텍스트는 자막과 심판 입력으로만 쓰임
  — 기획 문서의 "B-lite: STT 텍스트를 릴레이해 TTS로 재생"과 다르게 실제 오디오가 오간다.
- 발화 텍스트는 `t_start_ms`(통화 시작=0 기준 상대 시각) 붙여 서버가 단일 진실로 병합·저장.

---

## 4. 인크리멘탈 심판 (실시간 게임 층) — 배틀 전용

### 4.1 목적
협상 배틀에 격투 게임 같은 실시간 피드백을 부여. 통화를 막지 않는 비동기 사이드 채널.

### 4.2 클라이언트 반영 (`battle_call_screen.dart`, `battle_room.dart`)
| 요소 | 구현 |
|---|---|
| 기세 줄다리기 바 | 상단 고정, `TweenAnimationBuilder`로 부드럽게 애니메이션, 5~95% clamp |
| 이벤트 팝업 | 골드 배너, 2.5초 자동 소멸 |
| AI 코치 귓속말 | 화면 중단에 상시 노출(최신 힌트로 갱신), 본인 전용 |
| 비밀 카드 칩 | 하단 근처 접이식 — 접힘 시 목표/선/비밀 한 줄 아이콘 요약, 펼치면 5필드 전체 |
| 관전 캐스터 | 당사자 화면엔 미표시, `/ws/watch`로만 전송 |

### 4.3 판정 신뢰 장치
중간 게이지는 참고 지표일 뿐 — **최종 승패는 종료 후 정밀 심판(§3.2.3)이 결정**한다.

---

## 5. 음성 파이프라인 — 실제로는 플랫폼 통합, 서버 STT 단일 경로

### 5.1 STT — Android 온디바이스 방식은 폐기됨
`mosimosi/lib/platform/stt_factory.dart`가 명시하듯 **Android·Windows 공통 단일 구현**
(`WhisperSttEngine`)만 존재. `record` 패키지로 16kHz mono PCM16을 캡처해 게임 서버의
`/ws/stt` WebSocket 릴레이(`server/game/app/stt.py`)를 통해 `localhost:8765`의 faster-whisper
서버(`server/whisper/server.py`)로 전달한다. 기존 기획(Android `speech_to_text` 온디바이스 +
Windows만 서버 Whisper)은 실제로는 채택되지 않았다 — 실시간 오디오 릴레이(배틀)·오픈마이크에
raw PCM 캡처가 필요해 두 플랫폼을 record 기반으로 통일했다.

**발화 분절**: webrtcvad(30ms 프레임, 관대 모드) + RMS 게이트(기본 300, 순수 VAD만으론 무억제
마이크 소음 바닥이 문턱보다 높아 침묵 판정이 안 되는 문제 방어) 이중 게이트로 0.8초 무음을
감지해 분절. `MAX_SEGMENT_MS=10000` 강제 flush 안전망. `condition_on_previous_text=False`로
환청 전염 방지, `no_speech_prob<0.6` 세그먼트만 채택.

### 5.2 TTS — Qwen3-TTS 우선, Google Cloud TTS 폴백, 최종적으로 OS TTS
`server/game/app/tts.py`의 `/tts/synthesize` 우선순위:
1. **Qwen3-TTS(vLLM-Omni)** — `_QWEN_VOICE_MAP`이 클라이언트가 보내는 Chirp3-HD 보이스명 문자열을
   Qwen 화자(`uncle_fu`/`vivian`/`sohee`/`dylan`/`aiden`)·속도·seed·자연어 instructions로 매핑.
   감정 태그(§3.1.3)는 `_EMOTION_INSTRUCTION`으로 이 instructions에 순간 톤을 덧붙여 반영.
2. 실패/미설정 시 **Google Cloud TTS(Chirp3 HD)** 폴백(pause 마크업 자동 삽입)
3. 서버 자체가 503이면 클라이언트(`platform/impl/cloud_tts_engine.dart`)가 **OS 내장 TTS**
   (`flutter_tts`)로 최종 폴백
- 응답 포맷은 `wav` 고정(mp3는 일부 삼성 하드웨어 디코더에서 재생 정지 문제 확인돼 배제).

### 5.3 오디오 재생
- 보스 TTS·배틀 상대 음성 모두 `flutter_soloud` 기반 저지연 엔진(`SoundService`, `PcmStreamPlayer`)
  사용. 로비 BGM은 통화/배틀/관전 등 몰입 화면 진입 시 자동 음소거(suppress depth 카운터).

---

## 6. LLM 연동 — 서버 프록시 + task별 자동 분기

### 6.1 서빙 인프라 (`server/deploy/systemd/*.service` 기준)
- 자체 GPU 서버(camp-3, RTX 3090 24GB) 위에 3개 서비스 상시 구동: **vLLM**(`Qwen/Qwen3-14B-AWQ`,
  OpenAI 호환 API, 포트 8000) · **Qwen3-TTS(vLLM-Omni)** · **faster-whisper**(large-v3, int8_float16,
  로컬 전용 포트 8765). GPU 메모리를 세 서비스가 나눠 쓰는 구조라 경합 여지가 있음(운영 중 실측
  기반 watchdog으로 대응, §8).
- 게임 서버(FastAPI, 포트 8080)는 Cloudflare Tunnel로 `https://graceheeseo.madcamp-kaist.org`에
  공개.

### 6.2 태스크별 자동 분기 (`server/game/app/llm.py`)
```
POST /llm/chat { task, messages, temperature?, max_output_tokens?, session_id? }
```
| task | 기본 백엔드 | 사용처 |
|---|---|---|
| `boss_turn` | vLLM (VLLM_BASE_URL 설정 시) | 보스 대화 턴 |
| `incremental` | vLLM | 배틀 인크리멘탈 심판 |
| `final_judge` | Gemini | 배틀 최종 심판, 보스전 최종 심판+리포트 |
| `scenario` | Gemini | 랜덤 상황 변수 생성 |

- `LLM_FALLBACK=gemini` 환경변수로 전 태스크를 Gemini로 강제 전환 가능(자체 서버 다운 시 보험).
- 모든 요청/응답은 `llm_logs` 테이블에 기록(추후 파인튜닝 데이터 후보 — 실제 파인튜닝은 미구현).
- vLLM 호출 시 `top_p=0.6`, `repetition_penalty=1.05`, `enable_thinking=False`로 고정 — Qwen3가
  기본값(top_p=1.0)에서 저확률 CJK 토큰으로 중국어를 섞어 내는 문제, thinking 태그로 인한 지연
  폭증 문제를 각각 억제하기 위함.
- 클라이언트는 `llm_factory.dart`에서 `--dart-define=USE_FAKE_LLM=true`로 서버 없이 가짜 LLM
  구동 가능(개발용 E2E 테스트).

### 6.3 파인튜닝
`llm_logs`에 요청/응답이 쌓이고 있으나 **QLoRA 등 실제 파인튜닝 파이프라인은 미구현**(로깅만 존재).

---

## 7. 피드백 리포트

### 7.1 보스전 리포트 (`core/call/llm_tasks.dart::runFinalJudge`, Gemini 1회 호출로 판정+리포트 통합)
`cleared`(전 조건 달성 시만 true) · `score`(0~100) · `verdictLine` · 조건별 O/X + 근거 대사 인용
(`conditions`) · "이렇게 말했다면" 개선 제안 2~3개(`improvements`) · 말하기 습관 코멘트
(`deliveryNote`) · 군말/침묵 추정 횟수(`fillerCount`/`silenceCount`) · 하이라이트 명대사.

### 7.2 배틀 리포트 (결과 화면 3탭: 판정 / 비밀 공개 / 내 리포트)
- **판정**: 승패 배너 + 최종 기세 바 + 나·상대 각각의 루브릭(2~3항목, 1~5점 + 실제 대사 인용)
- **비밀 공개**: 나 vs 상대 카드를 나란히 — 목표·"선"(지켜냄/넘음 플래그)·비밀(들킴/안들킴 플래그)을
  실제 대사 인용과 함께 공개
- **내 리포트**: 결정적 발언(`keyQuote`) + "이렇게 말했다면"(`improvement`)

### 7.3 전적 대시보드 (`history_screen.dart`)
서버 세션 목록에서 클라이언트가 계산: 최근 7판 점수 추이 막대그래프, 평균 점수, 승률, 총 판수.
군말/침묵 평균 등 judge 파싱이 필요한 지표는 **미구현**(P2.5 표시로 남아있던 항목).

---

## 8. 안정성 — Whisper 워치독

GPU 3개 서비스 경합으로 whisper 프로세스가 CUDA 컨텍스트 손상(`out of memory` →
`invalid device ordinal`) 상태에 빠지면, `websockets` 라이브러리가 예외를 연결 단위로 삼켜
프로세스가 죽지 않으므로 systemd의 `Restart=always`가 트리거되지 않는다. 이를 감지·복구하기
위해 별도 워치독(`server/deploy/whisper_watchdog.py`, `yeoboseyo-whisper-watchdog.service`)이
60초마다 더미 오디오로 실제 전사 경로를 태워보고, 연속 3회 실패 시(오탐 방지 쿨다운 300초 적용)
`systemctl restart yeoboseyo-whisper`를 자동 실행한다. whisper 외 서비스(vLLM/Qwen-TTS)의
동일 유형 장애는 이 워치독의 감시 범위 밖.

---

## 9. 계정 · 전적 시스템

### 9.1 인증 (`server/game/app/auth.py`, `mosimosi/lib/services/auth_service.dart`)
- **소셜 로그인**(Google, Kakao): 앱이 로컬 loopback 서버(127.0.0.1:임의포트)를 열고 브라우저로
  서버 `/auth/{provider}/start`를 띄움 → OAuth 코드 교환 → `(provider, provider_id)`로 유저
  upsert → JWT(30일) 발급 → `http://127.0.0.1:{port}/callback?token=...`으로 앱에 반환.
- **일반 가입/로그인**(`local`): 이메일+bcrypt 해시 비밀번호. 이메일 인증·비밀번호 재설정은
  SMTP 인프라 없이 의도적으로 생략(데모 범위).
- JWT는 `flutter_secure_storage`에 저장, REST는 `Authorization: Bearer`, WebSocket은 쿼리
  파라미터로 전달.
- 온보딩 플로우: 컨셉 → 마이크 권한 → 로그인(소셜/이메일) → 닉네임(신규 계정만) → 첫 보스(chicken) 브리핑.

### 9.2 전적/도감 (`server/game/app/api.py`, `services/player_records.dart`)
- `GET /users/me/progress` — 보스별 격파 여부·최고점·도전 횟수
- `GET /users/me/sessions` — 목록(경량), `GET /users/me/sessions/{id}` — 상세(트랜스크립트+판정
  전체, 소유권 검증을 WHERE절에 포함해 "없음"과 "내 것 아님"을 구분 안 되는 404로 통일)
- `GET /users/me/battles` — 배틀 전적 집계(승/패/무·연승·역할별 승률·최근 10판)
- 배틀도 판정 종료 시 참가자별로 `sessions`(mode='battle')에 기록되어 전적 화면에 함께 집계됨.

### 9.3 미구현/스텁으로 남은 것
- **ELO 랭킹**: `users.elo`(기본 1500), `battle_players.elo_delta` 컬럼은 스키마에 존재하지만
  실제로 계산·갱신하는 코드가 없음(완전 스텁). 랭킹 화면·라우트 자체가 없음.
- **AI 상담원 배틀 폴백**: 매칭 30초 초과 시 UI만 있고 실제 서버 로직 없음("준비 중" 안내).
- **배틀 재접속 유예**: 통화 중 연결이 끊기면 `disconnected` 상태만 표시, 15초 유예 후 AI 이어받기/
  판 무효 로직은 TODO로 남아있음(`rooms.py`).

---

## 10. 관전 모드 (데스크톱 전용, 데모용)

- `GET /battles/live/latest`로 가장 최근 진행 중(`in_call`) 배틀 방을 조회 → `/ws/watch/{roomId}`
  읽기 전용 접속 → 접속 즉시 스냅샷(`watch_init`, 감독 시점 — 양측 비밀 목표 모두 노출) 수신 →
  이후 `state`/`utterance`/`judge` 이벤트 실시간 반영.
- 화면(`battle_watch_screen.dart`): 상단 양측 프로필+기세 바+타이머, 본문 양측 폰 모양 자막 패널
  2열(들키면 안 되는 비밀도 감독 시점으로 상시 노출). 실제 음성 재생은 없음(텍스트 자막만).
- 진입 경로: 설정 화면의 "개발자" 섹션(데스크톱에서만 노출) → "배틀 관전 (데모)".

---

## 11. 기술 스택 요약

| 분류 | 실제 사용 |
|---|---|
| 클라이언트 | Flutter(Dart) — Android + Windows, `go_router`, `flutter_soloud`, `record`, `flutter_secure_storage` |
| STT | 서버 faster-whisper(large-v3) — 두 플랫폼 공통, `record` 캡처 → WebSocket 릴레이 |
| TTS | Qwen3-TTS(vLLM-Omni) 우선 → Google Cloud TTS(Chirp3 HD) 폴백 → OS `flutter_tts` 최종 폴백 |
| 백엔드 | FastAPI(Python) — REST(유저/도감/전적) + WebSocket(매칭/배틀방/STT릴레이/관전) |
| LLM | vLLM(Qwen3-14B-AWQ, 보스 대화·인크리멘탈 심판) + Gemini(최종 심판·시나리오 변수) |
| DB | PostgreSQL — `users`/`boss_progress`/`battle_rooms`/`battle_players`/`sessions`/`utterances`/`llm_logs`/`judge_events` |
| 인증 | Google/Kakao OAuth(loopback) + 이메일/비밀번호(local), JWT |
| 인프라 | 자체 GPU 서버(camp-3, RTX 3090) + Cloudflare Tunnel, systemd 5개 서비스(game/vllm/whisper/whisper-watchdog + Qwen-TTS는 수동 기동) |

---

## 12. 알려진 제약 · 미해결 사항

1. ELO/랭킹 시스템 미구현(스키마만 존재)
2. 배틀 재접속 유예(15초) 로직 미구현 — 연결 끊김 시 즉시 `disconnected` 표시만
3. AI 상담원 배틀 폴백 미구현
4. GPU 3개 서비스(vLLM/Qwen-TTS/whisper) 동시 구동 시 메모리 경합 — whisper만 워치독으로 대응,
   vLLM/Qwen-TTS 쪽 동일 장애는 미대응
5. 전적 대시보드의 군말/침묵 평균 등 세부 지표는 세션별 judge 파싱이 필요해 미구현
6. QLoRA 등 실제 모델 파인튜닝은 미구현(요청/응답 로깅만 존재)
