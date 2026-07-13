import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/call/llm_tasks.dart';

/// JudgeResult.fromJson 방어 파싱 테스트.
/// LLM 응답은 필드 누락·타입 흔들림이 잦아, fromJson의 기본값/클램프 처리가
/// 실전 신뢰성의 핵심이다. 순수 Map-in 함수라 서비스 의존 없음.
void main() {
  group('JudgeResult.fromJson', () {
    test('완전한 JSON을 모든 필드로 파싱', () {
      final r = JudgeResult.fromJson({
        'cleared': true,
        'score': 87,
        'verdictLine': '조건 전부 달성',
        'conditions': [
          {'text': '주문 전달', 'met': true, 'evidence': '후라이드 한 마리요'},
        ],
        'improvements': [
          {'situation': '주소를 늦게 말함', 'better': '먼저 주소부터 불러주세요'},
        ],
        'deliveryNote': '군말이 잦음',
        'oneLiner': '치킨은 시켰다',
      });

      expect(r.cleared, isTrue);
      expect(r.score, 87);
      expect(r.verdictLine, '조건 전부 달성');
      expect(r.conditions, hasLength(1));
      expect(r.conditions.first.text, '주문 전달');
      expect(r.conditions.first.met, isTrue);
      expect(r.conditions.first.evidence, '후라이드 한 마리요');
      expect(r.improvements, hasLength(1));
      expect(r.improvements.first.situation, '주소를 늦게 말함');
      expect(r.improvements.first.better, '먼저 주소부터 불러주세요');
      expect(r.deliveryNote, '군말이 잦음');
      expect(r.oneLiner, '치킨은 시켰다');
    });

    test('빈 맵은 안전한 기본값으로 파싱', () {
      final r = JudgeResult.fromJson(const {});

      expect(r.cleared, isFalse);
      expect(r.score, 0);
      expect(r.verdictLine, '');
      expect(r.conditions, isEmpty);
      expect(r.improvements, isEmpty);
      expect(r.deliveryNote, '');
      expect(r.oneLiner, '');
    });

    test('score는 0~100으로 클램프', () {
      expect(JudgeResult.fromJson({'score': 150}).score, 100);
      expect(JudgeResult.fromJson({'score': -20}).score, 0);
      expect(JudgeResult.fromJson({'score': 100}).score, 100);
      expect(JudgeResult.fromJson({'score': 0}).score, 0);
    });

    test('score 소수는 반올림 후 클램프', () {
      expect(JudgeResult.fromJson({'score': 87.6}).score, 88);
      expect(JudgeResult.fromJson({'score': 87.2}).score, 87);
      expect(JudgeResult.fromJson({'score': 99.9}).score, 100);
    });

    test('score 누락 시 0', () {
      expect(JudgeResult.fromJson(const {}).score, 0);
      expect(JudgeResult.fromJson({'score': null}).score, 0);
    });

    test('cleared는 boolean true일 때만 true', () {
      expect(JudgeResult.fromJson({'cleared': true}).cleared, isTrue);
      expect(JudgeResult.fromJson({'cleared': false}).cleared, isFalse);
      // LLM이 문자열/숫자로 흘려도 오탐하지 않는다.
      expect(JudgeResult.fromJson({'cleared': 'true'}).cleared, isFalse);
      expect(JudgeResult.fromJson({'cleared': 1}).cleared, isFalse);
      expect(JudgeResult.fromJson({'cleared': null}).cleared, isFalse);
    });

    test('conditions 리스트의 비-맵 항목은 건너뜀', () {
      final r = JudgeResult.fromJson({
        'conditions': [
          {'text': '유효', 'met': true, 'evidence': '근거'},
          '깨진 문자열 항목',
          42,
          null,
          {'text': '유효2', 'met': false, 'evidence': ''},
        ],
      });
      expect(r.conditions, hasLength(2));
      expect(r.conditions[0].text, '유효');
      expect(r.conditions[1].text, '유효2');
    });

    test('improvements 리스트의 비-맵 항목은 건너뜀', () {
      final r = JudgeResult.fromJson({
        'improvements': [
          {'situation': 'a', 'better': 'b'},
          '깨짐',
          null,
        ],
      });
      expect(r.improvements, hasLength(1));
      expect(r.improvements.first.situation, 'a');
    });

    test('conditions 누락/null은 빈 리스트', () {
      expect(JudgeResult.fromJson(const {}).conditions, isEmpty);
      expect(JudgeResult.fromJson({'conditions': null}).conditions, isEmpty);
    });

    // 알려진 취약점(문서화): `as List? ?? const []`는 null만 방어하고
    // 잘못된 타입(문자열 등)은 못 막아 TypeError로 던진다. LLM이
    // {"conditions": "none"}을 뱉으면 크래시. 팀원(llm_tasks.dart 소유)이
    // 타입 가드로 강화하면 이 기대를 '빈 리스트'로 바꿔야 한다.
    test('SHARP EDGE: conditions가 잘못된 타입이면 현재 예외를 던진다', () {
      expect(() => JudgeResult.fromJson({'conditions': '아님'}), throwsA(isA<TypeError>()));
    });
  });

  group('ConditionResult.fromJson', () {
    test('met는 boolean true일 때만 true', () {
      expect(ConditionResult.fromJson({'met': true}).met, isTrue);
      expect(ConditionResult.fromJson({'met': 'true'}).met, isFalse);
      expect(ConditionResult.fromJson(const {}).met, isFalse);
    });

    test('text/evidence 누락 시 빈 문자열', () {
      final c = ConditionResult.fromJson(const {});
      expect(c.text, '');
      expect(c.evidence, '');
    });
  });

  group('Improvement.fromJson', () {
    test('situation/better 누락 시 빈 문자열', () {
      final i = Improvement.fromJson(const {});
      expect(i.situation, '');
      expect(i.better, '');
    });
  });
}
