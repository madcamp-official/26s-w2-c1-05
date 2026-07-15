/// 보스 데이터 모델 (FSD 3.1.1 / 3.1.3).
library;

/// 난이도 파라미터 (FSD 3.1.3) — 시스템 프롬프트에 텍스트로 렌더링된다.
class DifficultyParams {
  const DifficultyParams({
    required this.maxSentences, // 응답 길이 (1~2)
    required this.cooperativeness, // 협조성 1(비협조)~5(협조)
    required this.surpriseFreq, // 돌발 질문 빈도 1(없음)~5(매우 잦음)
    required this.interrupts, // 말 끊기 여부
  });

  final int maxSentences;
  final int cooperativeness;
  final int surpriseFreq;
  final bool interrupts;

  String render() => [
        '응답은 반드시 $maxSentences문장 이내의 짧은 한국어 구어체.',
        '협조성 $cooperativeness/5 (낮을수록 손님 요구를 잘 들어주지 않는다).',
        '돌발 질문 빈도 $surpriseFreq/5 (높을수록 예상 못 한 질문을 자주 던진다).',
        if (interrupts) '상대의 말이 길어지면 중간에 끊고 들어온다.',
      ].join('\n');
}

/// 모든 보스 공통 안전·형식 규칙 (FSD 3.1.3 / 6.3).
/// TTS 표현 규칙: 쉼표는 서버(tts.py)가 Chirp3 HD pause 태그로 자동 변환해
/// 실제 호흡처럼 들리게 하므로, 여기서 쉼표를 자연스럽게 쓰라고 지시하는 것이
/// 곧 TTS 리듬 개선으로 직결된다.
const String bossCommonRules = '''
[공통 규칙]
- 인신공격, 욕설, 비하 금지. 실존 업체·인물·전화번호 언급 금지.
- 전화 통화 상황을 절대 벗어나지 마라. 지문·해설 없이 대사만 말해라.
- 항상 한국어 구어체로만 답한다.

[TTS 표현 규칙 — 음성으로 자연스럽게 들리도록]
- 쉼표로 숨쉴 지점을, 말줄임표(…)로 머뭇거림을, 느낌표로 강조를 나타내라.
- "아이고", "하아…", "어어" 같은 감탄사·필러를 자연스럽게 섞어 써도 좋다.
- 숫자·시간은 한글로 표기하라 (예: "3시 30분" → "세시 반", "7조 2항" → "칠조 이항").

[감정 태그 — 목소리 감정 표현용]
- 매 응답의 맨 앞에 지금 이 대사의 감정을 대괄호로 하나만 붙여라. 그 다음에 대사를 이어라.
- 감정은 반드시 다음 중 하나: [평온] [상냥] [짜증] [분노] [미안] [당황]
- 대화 맥락에 맞게 감정을 바꿔라. 예: 평소엔 [상냥], 손님이 자꾸 못 알아들으면 [짜증], 규정을 어기라 하면 [분노].
- 예시: "[짜증] 아니 그 시간은 안 된다고 말씀드렸잖아요." / "[상냥] 네~ 어떤 걸로 도와드릴까요?"''';

/// 도감 티어 (디자인: normal=슬레이트, rare=스카이, boss=레드, legend=골드).
enum BossTier { normal, rare, boss, legend }

/// 보스전 TTS 보이스 프리셋 (`/tts/synthesize` 서버 프록시용).
/// 서버가 [voiceName]을 보고 Qwen3-TTS(omni) 화자로 매핑해 우선 시도하고,
/// 실패 시에만 아래 Chirp3 HD 필드(폴백 안전망)로 합성한다 — Qwen 화자/속도/
/// 감정지시는 서버의 매핑 테이블에서 관리하므로 클라이언트 변경 없이 튜닝된다.
/// [voiceName]은 `ko-KR-Chirp3-HD-*` 등 Cloud TTS voice 리소스명 그대로.
/// [pace]는 speakingRate(0.25~2.0, 1.0=기본 속도). [pitch]는 semitone(-20~20)이며
/// Chirp3 HD는 pitch를 지원하지 않아 서버에서 무시된다 — Neural2 폴백 보이스 전용.
class TtsVoicePreset {
  const TtsVoicePreset({
    required this.voiceName,
    this.pace = 1.0,
    this.pitch,
  });

  final String voiceName;
  final double pace;
  final double? pitch;
}

/// 인트로 씬(메신저 스토리)의 메시지 한 건 (디자인 2a·IntroScene).
/// 타이핑 인디케이터·도착 애니메이션은 화면이 재생 연출로 처리한다.
enum IntroMessageKind { mine, minePhoto, friend, friendPhoto, system }

class IntroMessage {
  const IntroMessage({
    required this.kind,
    this.text = '',
    this.caption = '', // 사진 메시지 설명
    this.file = '', // 사진 파일명 표기
    required this.time,
  });

  final IntroMessageKind kind;
  final String text;
  final String caption;
  final String file;
  final String time; // '오후 7:41'
}

/// 보스전 도입 스토리 — 메시지가 순차 재생되고 마지막에 고객센터 번호 +
/// 발신 버튼으로 보스전에 진입한다 (디자인 2a).
class IntroStory {
  const IntroStory({
    required this.friendName,
    required this.contextLabel, // '3월 12일 · 택배 도착 직후'
    required this.timeCapsule, // 대화 시작 시각 캡슐
    required this.messages,
    required this.callCardTitle, // '급배송 고객센터'
    required this.phoneNumber, // '1588-0424'
    this.incoming = false, // true = 걸려오는 상황(상대가 전화), false = 거는 상황
  });

  final String friendName;
  final String contextLabel;
  final String timeCapsule;
  final List<IntroMessage> messages;
  final String callCardTitle;
  final String phoneNumber;
  final bool incoming;

  String get friendInitial => friendName.substring(0, 1);
}

class Boss {
  const Boss({
    required this.id,
    required this.number,
    required this.name,
    required this.subtitle,
    required this.quote,
    required this.tier,
    required this.difficultyLevel,
    required this.portraitSyllable,
    required this.scenario,
    required this.personaPrompt,
    required this.clearConditions,
    required this.timeLimit,
    required this.difficulty,
    required this.voicePreset,
    this.introStory,
  });

  final String id;
  final int number; // 도감 번호 (No.00X)
  final String name;
  final String subtitle; // 도감/발신자 서브라벨
  final String quote; // 대표 대사 (브리핑 「…」)
  final BossTier tier;
  final int difficultyLevel; // 별 1~5 (표시용)
  final String portraitSyllable; // 타이포 초상 (디자인 규칙: 첫 음절)
  final String scenario; // 브리핑 용건
  final String personaPrompt; // 페르소나 + few-shot 3개
  final List<String> clearConditions;
  final Duration timeLimit;
  final DifficultyParams difficulty;
  final TtsVoicePreset voicePreset;
  final IntroStory? introStory; // null = 인트로 없이 바로 통화

  /// 판 시작 시 최종 시스템 프롬프트 조립 — 랜덤 변수(FSD 3.1.3) 주입.
  String buildSystemPrompt(List<String> variables) => [
        personaPrompt,
        '[난이도]',
        difficulty.render(),
        if (variables.isNotEmpty) ...[
          '[이번 판 상황 변수 — 대화 중 자연스럽게 드러내라]',
          for (final v in variables) '- $v',
        ],
        bossCommonRules,
      ].join('\n\n');
}
