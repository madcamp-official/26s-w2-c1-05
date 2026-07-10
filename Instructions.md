# Project specification: 여보세요 (콜포비아 실전 트레이닝 게임)

## 프로젝트 개요
전화 공포(콜포비아)를 게임으로 극복하는 크로스 플랫폼 앱.
- AI 보스와 전화 보스전(싱글) + 유저 간 실시간 전화 배틀(멀티)
- Flutter 단일 코드베이스 → **Android 앱 + Windows 데스크톱 앱** (iOS/웹 타겟 없음)
- 설계 문서: `docs/FSD.md`, `docs/IA.md` — 기능·화면 구현 전 반드시 해당 섹션을 읽을 것

## 절대 규칙 (위반 금지)

### 1. 플랫폼 의존성 격리
- `lib/core/`, `lib/features/` 에서 `dart:io`, `speech_to_text`, `flutter_tts`, `record` 등 플랫폼/플러그인 직접 import **금지**
- 플랫폼 기능은 반드시 `lib/platform/` 의 추상 인터페이스를 통해서만 접근
- 새 플랫폼 기능이 필요하면: ① `lib/platform/`에 인터페이스 추가 → ② `lib/platform/impl/`에 구현체 → ③ DI로 주입
- 구현체 선택은 조건부 import 또는 팩토리에서만

### 2. 비밀 정보 격리 (배틀)
- 배틀의 비밀 목표·규정 카드는 **서버가 각 클라이언트에 자기 몫만 전송**. 전체 시나리오 JSON을 클라이언트에 보내고 UI에서 가리는 구현 금지
- 관전(/watch) 스트림 페이로드에 비밀 정보 포함 금지

### 3. 채점은 타임스탬프 기준
- 모든 발화 기록은 `{speaker, text, tStartMs}` (tStartMs = 통화 시작 기준 상대 시각)
- 제한 시간·심판 컷오프 판정은 서버 수신 시각이 아니라 `tStartMs` 기준 (STT 지연 비대칭 대응)

### 4. LLM 호출은 추상화 경유
- LLM 호출은 `LlmClient` 인터페이스로만. 구현체: `VllmClient`(자체 서빙), `GeminiClient`
- 환경변수 `LLM_FALLBACK=gemini` 설정 시 전 태스크 Gemini로 전환 가능해야 함 (데모 보험)
- 태스크 배분: 보스 대화·인크리멘탈 심판 → vLLM / 최종 심판·리포트·시나리오 생성 → Gemini
- API 키는 서버에만. 클라이언트에서 LLM 직접 호출 금지 (게임 서버 프록시 경유)

### 5. 음성 데이터
- 음성 원본을 DB에 저장 금지. STT 텍스트만 저장
- Whisper 정제용 오디오는 처리 후 즉시 삭제

## 아키텍처

### 클라이언트 (Flutter)
```
lib/
  core/          # 게임 로직, 상태, 모델 (플랫폼 무관)
  features/      # 화면별 UI + 상태 (bosses, battle, call, history, home, onboarding)
  platform/      # 추상 인터페이스: SttEngine, TtsEngine, AudioRecorder
    impl/        # android_stt.dart, desktop_stt.dart(서버 Whisper), ...
  services/      # 게임 서버 API/WebSocket 클라이언트
  ui/            # 공통 위젯, 테마, 반응형 브레이크포인트
docs/            # 명세서, IA (설계 진실의 원천)
```

### 핵심 인터페이스 시그니처
```dart
abstract class SttEngine {
  Stream<SttResult> get results;        // SttResult{text, isFinal, tStartMs}
  Future<void> start(); Future<void> stop();
  bool get isAvailable;                 // false면 UI가 텍스트 입력 폴백 표시
}
abstract class TtsEngine {
  Future<void> speak(String text, {double pitch, double rate});
  Future<void> stopSpeaking();
}
abstract class AudioRecorder {          // 데스크톱 STT + Whisper 정제 트랙용
  Stream<List<int>> startChunks();      // 오디오 청크 스트림
  Future<void> stop();
}
```

### 백엔드 (게임 서버)
- REST(도감·전적) + WebSocket(매칭·배틀 방·타이머·트랜스크립트 수집)
- LLM 프록시: 키 은닉, 요청 큐, 429 지수 백오프(1s→2s→4s)
- 배틀 방 상태 머신: `waiting → matched → briefing → in_call → judging → done` (+ aborted)
- ML 서버(별도, RTX 3090): vLLM(Qwen3-14B AWQ, --max-model-len 4096, guided decoding) + faster-whisper small

## UI 규칙
- 모든 화면은 모바일(세로) 우선 구현 → 데스크톱 레이아웃은 반응형 분기로 추가
- 레이아웃 규칙: 통화 화면만 데스크톱에서 "중앙 고정폭(~300px) 폰 목업 + 양옆 HUD 패널", 나머지(홈·도감·전적)는 네이티브 와이드 그리드 — 폰 목업 금지
- 통화 화면은 막다른 방: 통화 중 GNB 숨김, 이탈은 "끊기"만
- 텍스트 입력 폴백: STT `isAvailable == false` 시 모든 통화 화면에서 텍스트 입력 제공

## 개발 규약
- 한 번에 한 화면/기능 단위로 작업. 각 단위는 빌드·실행 확인 후 다음으로
- 보스 응답은 1~2문장 강제(프롬프트), LLM 응답은 스트리밍 수신 → 첫 문장 완성 즉시 TTS
- 대화 히스토리는 6~8턴 유지, 초과분 요약 치환
- vLLM으로 가는 모든 Gemini 프롬프트/응답은 로깅 (향후 QLoRA 데이터)
- 커밋 전: `flutter analyze` 통과 확인
