import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/call/call_session.dart';
import 'package:mosimosi/core/call/llm_tasks.dart';
import 'package:mosimosi/core/data/bosses.dart';
import 'package:mosimosi/services/fake_llm_client.dart';
import 'package:mosimosi/services/llm_client.dart';

/// FakeLlmClient가 실제 소비처 계약을 지키는지 검증 — fake의 출력 형식이
/// 어긋나면 통화(문장 큐 TTS)·시나리오·최종 심판이 조용히 무너지므로,
/// 직접 파싱하지 않고 소비자 함수(llm_tasks)를 그대로 통과시킨다.
void main() {
  const llm = FakeLlmClient();
  final boss = bossesSeed.first;

  group('FakeLlmClient', () {
    test('boss_turn: 문장부호로 끝나는 응답을 델타 스트리밍', () async {
      final chunks = await llm.chatStream(const [
        LlmMessage(role: 'system', content: '페르소나'),
        LlmMessage(role: 'user', content: '안녕하세요'),
      ]).toList();

      expect(chunks.length, greaterThan(1)); // 단발이 아닌 스트리밍
      final full = chunks.join();
      // call_session._sentenceEnd와 동일 규칙 — 매치가 있어야 TTS 큐 투입
      // (= 첫 발성 = active 승격)이 일어난다.
      expect(RegExp(r'[.!?。！？…\n]').hasMatch(full), isTrue);
    });

    test('scenario: generateScenarioVariables가 변수 리스트를 얻는다', () async {
      final vars = await generateScenarioVariables(llm: llm, boss: boss);
      expect(vars, isNotEmpty);
    });

    test('final_judge: runFinalJudge가 보스 조건 그대로의 판정을 얻는다', () async {
      final judge = await runFinalJudge(
        llm: llm,
        boss: boss,
        transcript: const [
          Utterance(speaker: 'boss', text: '네, 여보세요.', tStartMs: 0),
          Utterance(speaker: 'user', text: '후라이드 한 마리 주문할게요.', tStartMs: 1200),
        ],
        endReason: CallEndReason.hangUp,
      );

      expect(judge.score, inInclusiveRange(0, 100));
      // 프롬프트의 클리어 조건 목록을 그대로 되돌려야 결과 화면이 실데이터 모양.
      expect([for (final c in judge.conditions) c.text], boss.clearConditions);
      expect(judge.improvements, isNotEmpty);
    });
  });
}
