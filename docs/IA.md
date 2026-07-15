# 여보세요 — Information Architecture (IA)

> 실제 라우트 구조(`mosimosi/lib/core/router.dart`)와 화면 구현을 기준으로 작성됨.

---

## 1. IA 설계 원칙

1. **홈 = 게임 로비**: 진입 즉시 "AI 대전 / 실전 배틀" 두 모드 카드가 지배적.
2. **두 폼팩터는 동등한 게임 클라이언트**: 데스크톱도 모든 화면·모드를 완전 지원. 폼팩터 차이는
   레이아웃 차이일 뿐, 기능 삭제가 아님(`isDesktop(context)` 분기).
3. **통화 화면은 막다른 방**: `PopScope(canPop: false)`로 시스템 뒤로가기 차단, 이탈은 "끊기/종료"
   버튼으로만.
4. **비밀 정보는 서버 단에서부터 분리**: 배틀 브리핑의 비밀 목표·규칙은 서버가 매칭 시점에 역할별로
   나눠 전송(상대 몫은 아예 전송하지 않음). 관전 스트림은 예외적으로 감독 시점(양측 비밀 노출)으로
   설계됨 — §7 참고.
5. **결과 → 재도전 루프 최단화**: 재도전/다음 보스/재매칭 버튼이 결과 화면 CTA에 항상 존재.
6. **리포트는 결과 화면에 내장**: 별도 학습 섹션이 아니라 결과 화면의 탭.

---

## 2. 폼팩터별 레이아웃 규칙

| 화면 성격 | 모바일 | 데스크톱 |
|---|---|---|
| 통화(싱글/배틀) | 세로 전화 UI 단일 컬럼 | 중앙 고정폭 폰 목업 + 좌우 HUD 패널(`CallDesktopStage`/`buildCallDesktopStage`) |
| 넓게 펴지는 화면(홈·도감·전적·배틀 로비) | 세로 스크롤 / 2열 그리드 | 네이티브 와이드(다열 그리드 또는 2~3컬럼) |

**데스크톱 통화 화면 구성** (`boss_call_screen.dart`/`battle_call_screen.dart` desktop 분기):
- 중앙 고정폭: 발신자·실시간 자막·마이크 상태 — 모바일과 동일한 폰 위젯 재사용
- 좌측 패널: (싱글) 달성 조건 체크리스트 / (배틀은 별도 secretChip 방식이라 좌우 HUD 패널 미사용,
  칩이 폰 목업 안에 인라인으로 위치)
- 우측 패널: 캡션 로그(전체 발화 히스토리)

---

## 3. 사이트맵 (실제 라우트 트리)

```
여보세요 (Android 앱 / Windows 데스크톱 앱 — 동일 트리)
│
├── /onboarding                     온보딩 4단계 (컨셉→마이크→로그인→닉네임)
│
├── [셸: 하단 탭바(모바일) / 좌측 NavigationRail(데스크톱)]
│   ├── /home                       1. 홈 (게임 로비)
│   │
│   ├── /bosses                     2.1 보스 도감 "진상 도감" (6종, 잠금 없음)
│   │   └── /bosses/:id             2.2 브리핑
│   │       ├── /bosses/:id/intro           (셸 밖) 인트로 스토리 — 있는 보스만
│   │       ├── /bosses/:id/call            (셸 밖) ★통화 화면 — 막다른 방
│   │       └── /bosses/:id/result/:sessionId  (셸 밖) 결과(판정/리포트 탭)
│   │
│   ├── /battle                     3a. 배틀 로비 (전적 요약 + 매칭 시작 CTA)
│   │
│   └── /history                    4.1+4.2 전적 (대시보드 + 목록, 필터 칩)
│       └── /history/:sessionId     4.2.1 전적 상세 (트랜스크립트 + 판정)
│
├── /battle/matching                (셸 밖) 3.1 매칭 대기 → 성사 → 30초 폴백 시트
├── /battle/:roomId/brief           (셸 밖) 3.2 비공개 브리핑 ★프라이빗
├── /battle/:roomId/call            (셸 밖) ★3.3 배틀 통화 — 막다른 방
├── /battle/:roomId/result          (셸 밖) 3.5 배틀 결과 (판정/비밀공개/내리포트 3탭)
├── /battle/:roomId/watch           (셸 밖) 5. 관전 (데스크톱, 설정→개발자 진입)
│
└── /settings                       (셸 밖) 6. 설정
```

- **GNB는 3탭이 아니라 4탭**: 홈 / 도감 / 배틀 / 전적 (`main_shell.dart` — 배틀 로비가 정식
  GNB 탭으로 승격돼 있음. 예전 IA의 "배틀은 GNB가 아니라 홈 CTA로만" 원칙은 실제로는 채택되지 않음).
- **랭킹(`/ranking`) 라우트는 없음** — ELO 시스템이 미구현이라 화면 자체가 존재하지 않음.
- 통화/배틀 라우트는 세션 유효성 검사(예: `BattleRoomController.of(roomId)`가 null이면 "세션이
  만료됐어요" 화면)로 방어하지만, 브리핑을 건너뛰고 직접 진입 시 자동 리다이렉트는 없음(컨트롤러가
  없으면 에러 화면 표시 후 사용자가 직접 뒤로 나가야 함).

---

## 4. 글로벌 네비게이션

| 탭 | 진입 라우트 | 아이콘 |
|---|---|---|
| 홈 | `/home` | `Icons.home` |
| 도감 | `/bosses` | `Icons.menu_book` |
| 배틀 | `/battle` | `Icons.bolt` |
| 전적 | `/history` | `Icons.insights` |

- 모바일: `NavigationBar`(하단 탭바) — `MainShell`
- 데스크톱: `NavigationRail`(좌측 세로) — 같은 4개 목적지, `labelType: all`
- 우상단(모바일)/헤더(데스크톱) 프로필 아이콘 → `/settings`(풀스크린 push)
- GNB 숨김 화면: 통화(2.3/3.3), 배틀 매칭/브리핑/결과/관전, 온보딩, 설정

---

## 5. 핵심 사용자 플로우

### F1. 첫 방문 → 첫 클리어
`/onboarding`(컨셉→마이크 권한→소셜/이메일 로그인→닉네임) → `/home` → `/bosses/chicken`
(닉네임 제출 시 자동 이동) → 브리핑 → (인트로 있으면 재생) → 통화 → 결과 "다음 보스" → 도감

### F2. 보스전 반복 루프
`/bosses` → `/bosses/:id`(브리핑) → 통화 → 결과(재도전|다음 보스|도감) → `/bosses`

### F3. 배틀 풀 플로우 (크로스 폼팩터)
`/battle`(로비) → `/battle/matching` → 매칭 성사 시 `BattleRoomController` 생성 및 방 소켓 즉시
연결 → `/battle/:roomId/brief`(양측 준비완료 시 서버가 `in_call`로 전환) → `/battle/:roomId/call`
→ 통화 종료(judging) 즉시 `/battle/:roomId/result` 이동(판정 도착 전엔 스피너) → 재매칭|홈
- 30초 미매칭 시 폴백 시트("AI와 배틀하기"는 미구현 안내, "계속 기다리기"로 큐 유지)
- 통화 중 서버 연결 끊김 → `disconnected` 상태 배너만 표시, 15초 유예 로직은 없음(TODO)

### F4. 관전 플로우 (데모)
설정 → 개발자 섹션 → "배틀 관전(데모)" → `GET /battles/live/latest`로 진행 중인 방 조회 →
`/battle/:roomId/watch` → 감독 시점(양측 비밀 모두 노출) 실시간 중계

### F5. 리포트 회고
`/history` → `/history/:sessionId` → 트랜스크립트 + 당시 판정(조건 O/X, 개선 제안) 재확인

---

## 6. 화면별 콘텐츠 인벤토리 (우선순위 순)

### 2.3 보스 통화 화면 (`boss_call_screen.dart`)
1. Push-to-talk 버튼(PTT 모드) 또는 오픈마이크 상태 필(기본값)
2. 보스 인내심 게이지 + 통화 타이머(상단)
3. 실시간 자막 — 모바일 직전 3발화 / 데스크톱 우측 전체 로그 패널
4. 이벤트 팝업(침묵 경고·남은 시간 30초 등, 2초 자동 소멸)
5. 달성 조건 — 모바일 접이식 칩 / 데스크톱 좌측 패널 상시 노출 (실시간 체크 아님, 판정은 종료 후)
6. 종료 버튼

### 3.3 배틀 통화 화면 (`battle_call_screen.dart`, 싱글과의 차이)
- 인내심 게이지 → 기세 줄다리기 바(양측 공통, 서버 인크리멘탈 심판이 갱신)
- 비밀 카드 칩(접이식, 목표/선/비밀 아이콘 요약 ↔ 5필드 전체 펼침)
- AI 코치 귓속말 상시 노출(본인 전용)
- 인크리멘탈 심판 이벤트 배너(골드, 2.5초)
- 6초간 양측 침묵 시 "첫마디를 시작해보세요" 제안 팝업(내 몫의 `openingLine`)
- Push-to-talk 대신 오픈마이크 기본(설정에서 PTT로 전환 가능)

### 3.5 배틀 결과 화면 탭 순서
탭A 판정(승패 먼저) → 탭B 비밀 공개(연출) → 탭C 내 리포트 — 감정 소화 후 학습이라는 근거 유지.

---

## 7. 상태 모델

### 보스 카드
`unlocked(항상) → cleared(best_score)` — `locked` 상태는 존재하지 않음(전부 처음부터 해금).

### 배틀 방(room) — 서버 기준 (`Room.state`)
| 상태 | 화면 |
|---|---|
| matched | 매칭 완료 직후 |
| briefing | 3.2 브리핑 (양측 ready 대기) |
| in_call | 3.3 통화 (+ 5 관전) |
| judging | 3.5 진입 직후 스피너(판정 대기) |
| done | 3.5 결과 표시 |
| (클라이언트 로컬) disconnected | 서버 연결 끊김 — done 도달 전 |

### 통화 화면 내부 (`CallPhase`, 싱글 기준)
`connecting → ringing → active → silenceWarning → last30s → ended`
(배틀은 `BattleRoomController.state`를 그대로 반영, 별도 내부 phase 없음)

---

## 8. 라우트 구조 (실제, `router.dart` 그대로)

```
/onboarding
/home
/bosses
/bosses/:id
/bosses/:id/intro
/bosses/:id/call
/bosses/:id/result/:sessionId
/battle
/battle/matching
/battle/:roomId/brief
/battle/:roomId/call
/battle/:roomId/result
/battle/:roomId/watch
/history
/history/:sessionId
/settings
```
`/ranking` 라우트는 존재하지 않음(§3 참고).

---

## 9. 미해결 / 알려진 갭

1. 통화·배틀 라우트 직접 진입 시 세션 유효성 검사 후 자동 리다이렉트는 없음(에러 화면만 표시)
2. 배틀 재접속 유예(15초) 미구현
3. AI 상담원 배틀 폴백 미구현(UI 문구만 존재)
4. ELO 랭킹 화면·라우트 없음
5. 관전 진입은 "설정 → 개발자" 경로 하나뿐 — 공유 링크/코드 기반 진입은 미구현
