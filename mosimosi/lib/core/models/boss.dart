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
const String bossCommonRules = '''
[공통 규칙]
- 인신공격, 욕설, 비하 금지. 실존 업체·인물·전화번호 언급 금지.
- 전화 통화 상황을 절대 벗어나지 마라. 지문·해설 없이 대사만 말해라.
- 항상 한국어 구어체로만 답한다.''';

/// 도감 티어 (디자인: normal=슬레이트, rare=스카이, boss=레드, legend=골드).
enum BossTier { normal, rare, boss, legend }

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
