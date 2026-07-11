import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/data/bosses.dart';
import 'package:mosimosi/core/models/boss.dart';

/// 보스 시드 데이터 정합성 테스트. 시드는 게임의 진실의 원천(코드 시드)이므로
/// 깨지면 도감·보스전이 통째로 오동작한다 — 데이터 회귀 가드.
void main() {
  group('bossesSeed 정합성', () {
    test('시드가 비어있지 않다', () {
      expect(bossesSeed, isNotEmpty);
    });

    test('id가 모두 고유하다', () {
      final ids = bossesSeed.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('각 보스의 필수 텍스트 필드가 비어있지 않다', () {
      for (final b in bossesSeed) {
        expect(b.id, isNotEmpty, reason: 'id');
        expect(b.name, isNotEmpty, reason: '${b.id}.name');
        expect(b.scenario, isNotEmpty, reason: '${b.id}.scenario');
        expect(b.personaPrompt, isNotEmpty, reason: '${b.id}.personaPrompt');
        expect(b.portraitSyllable, hasLength(1), reason: '${b.id}.portraitSyllable(첫 음절 1자)');
      }
    });

    test('클리어 조건이 최소 1개 이상이다', () {
      for (final b in bossesSeed) {
        expect(b.clearConditions, isNotEmpty, reason: b.id);
      }
    });

    test('제한 시간이 양수다', () {
      for (final b in bossesSeed) {
        expect(b.timeLimit, greaterThan(Duration.zero), reason: b.id);
      }
    });

    test('난이도 파라미터가 정의된 범위 안에 있다', () {
      for (final b in bossesSeed) {
        final d = b.difficulty;
        expect(d.maxSentences, greaterThanOrEqualTo(1), reason: '${b.id}.maxSentences');
        expect(d.cooperativeness, inInclusiveRange(1, 5), reason: '${b.id}.cooperativeness');
        expect(d.surpriseFreq, inInclusiveRange(1, 5), reason: '${b.id}.surpriseFreq');
      }
    });

    test('각 보스의 시스템 프롬프트 조립이 예외 없이 동작하고 공통 규칙을 포함한다', () {
      for (final b in bossesSeed) {
        final p = b.buildSystemPrompt(const []);
        expect(p, contains(bossCommonRules), reason: b.id);
      }
    });
  });

  group('bossById', () {
    test('존재하는 id로 정확한 보스를 반환한다', () {
      for (final b in bossesSeed) {
        expect(bossById(b.id)?.id, b.id);
      }
    });

    test('없는 id는 null을 반환한다', () {
      expect(bossById('__nope__'), isNull);
      expect(bossById(''), isNull);
    });
  });
}
