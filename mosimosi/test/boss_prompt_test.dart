import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/models/boss.dart';

/// Boss.buildSystemPrompt / DifficultyParams.render 순수 문자열 조립 테스트.
/// 이 조립이 어긋나면 보스 프롬프트가 통째로 잘못 나가므로 회귀 가드로 둔다.
void main() {
  group('DifficultyParams.render', () {
    test('숫자 파라미터가 렌더 문자열에 반영된다', () {
      final r = const DifficultyParams(
        maxSentences: 2,
        cooperativeness: 3,
        surpriseFreq: 5,
        interrupts: false,
      ).render();
      expect(r, contains('2문장'));
      expect(r, contains('협조성 3/5'));
      expect(r, contains('돌발 질문 빈도 5/5'));
    });

    test('interrupts=true면 말 끊기 지시가 포함된다', () {
      final r = const DifficultyParams(
        maxSentences: 1,
        cooperativeness: 1,
        surpriseFreq: 4,
        interrupts: true,
      ).render();
      expect(r, contains('중간에 끊고'));
    });

    test('interrupts=false면 말 끊기 지시가 없다', () {
      final r = const DifficultyParams(
        maxSentences: 2,
        cooperativeness: 5,
        surpriseFreq: 1,
        interrupts: false,
      ).render();
      expect(r, isNot(contains('중간에 끊고')));
    });
  });

  group('Boss.buildSystemPrompt', () {
    Boss makeBoss() => const Boss(
          id: 'test',
          name: '테스트 보스',
          subtitle: 'sub',
          portraitSyllable: '테',
          scenario: '시나리오',
          personaPrompt: 'PERSONA_MARKER',
          clearConditions: ['조건1'],
          timeLimit: Duration(minutes: 3),
          difficulty: DifficultyParams(
            maxSentences: 2,
            cooperativeness: 3,
            surpriseFreq: 4,
            interrupts: false,
          ),
        );

    test('페르소나·난이도·공통규칙이 모두 포함된다', () {
      final p = makeBoss().buildSystemPrompt(const []);
      expect(p, contains('PERSONA_MARKER'));
      expect(p, contains('[난이도]'));
      expect(p, contains('협조성 3/5'));
      expect(p, contains(bossCommonRules));
    });

    test('변수가 비면 상황 변수 섹션이 없다', () {
      final p = makeBoss().buildSystemPrompt(const []);
      expect(p, isNot(contains('상황 변수')));
    });

    test('변수가 있으면 각 항목이 불릿으로 주입된다', () {
      final p = makeBoss().buildSystemPrompt(['품절: 양념치킨', '이벤트: 콜라 증정']);
      expect(p, contains('상황 변수'));
      expect(p, contains('- 품절: 양념치킨'));
      expect(p, contains('- 이벤트: 콜라 증정'));
    });

    test('페르소나가 맨 앞, 공통 규칙이 맨 뒤 순서', () {
      final p = makeBoss().buildSystemPrompt(const []);
      expect(p.indexOf('PERSONA_MARKER'), lessThan(p.indexOf(bossCommonRules)));
      expect(p.indexOf('[난이도]'), lessThan(p.indexOf(bossCommonRules)));
    });
  });
}
