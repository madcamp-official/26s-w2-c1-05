import 'dart:convert';

import 'llm_client.dart';

/// 개발용 가짜 LLM — 서버 프록시 없이 데스크톱에서 통화 플로우 E2E 테스트.
/// `flutter run --dart-define=USE_FAKE_LLM=true`로만 활성 (llm_factory.dart).
///
/// 소비처 계약을 그대로 지킨다:
/// - boss_turn(기본): 문장부호로 끝나는 델타 스트리밍 → call_session의
///   문장 큐 TTS 투입·active 승격이 실제로 동작.
/// - scenario: `{"variables": [...]}` JSON (llm_tasks.generateScenarioVariables).
/// - final_judge: JudgeResult.fromJson 스키마 JSON (llm_tasks.runFinalJudge).
class FakeLlmClient implements LlmClient {
  const FakeLlmClient();

  /// assistant 발화 수로 순환 — 턴마다 다른 문장이 나와 흐름 확인이 쉽다.
  static const _bossReplies = [
    '네, 여보세요. 무엇을 도와드릴까요?',
    '아 네, 알겠습니다. 조금 더 자세히 말씀해 주시겠어요?',
    '네네, 확인했습니다. 혹시 다른 필요하신 건 없으세요?',
    '네, 그렇게 처리해 드릴게요. 더 궁금하신 점 있으세요?',
  ];

  @override
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    String task = 'boss_turn',
    double? temperature,
    int? maxOutputTokens,
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 300)); // 네트워크 흉내
    switch (task) {
      case 'scenario':
        yield jsonEncode({
          'variables': [
            '(가짜) 오늘 양념 소스가 품절이다',
            '(가짜) 신규 고객 배달비 무료 이벤트 중이다',
          ],
        });
      case 'final_judge':
        yield _judgeJson(messages);
      default: // boss_turn·incremental — 몇 글자씩 흘려 스트리밍 UI를 실제로 태운다
        final reply = _bossReplies[
            messages.where((m) => m.role == 'assistant').length %
                _bossReplies.length];
        final runes = reply.runes.toList();
        for (var i = 0; i < runes.length; i += 3) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          yield String.fromCharCodes(
              runes.sublist(i, (i + 3).clamp(0, runes.length)));
        }
    }
  }

  /// 심판 프롬프트의 "[클리어 조건]" 번호 목록(`1. …`)을 되읽어 전부 달성 처리 —
  /// 결과 화면(조건 O/X·리포트)이 보스별 실데이터 모양으로 렌더되게 한다.
  String _judgeJson(List<LlmMessage> messages) {
    final prompt = messages.isEmpty ? '' : messages.last.content;
    final conditions = [
      for (final m
          in RegExp(r'^\d+\.\s*(.+)$', multiLine: true).allMatches(prompt))
        {'text': m.group(1)!.trim(), 'met': true, 'evidence': '(가짜 심판) 인용 생략'},
    ];
    return jsonEncode({
      'cleared': true,
      'score': 85,
      'verdictLine': '(가짜 심판) 조건을 모두 달성한 것으로 처리했어요.',
      'conditions': conditions,
      'improvements': [
        {'situation': '(가짜) 어… 그게…', 'better': '(가짜) 용건을 먼저 한 문장으로 말해 보세요.'},
      ],
      'deliveryNote': '(가짜 심판) 실제 평가가 아닙니다 — USE_FAKE_LLM 모드.',
      'oneLiner': '오늘도 가짜 보스는 관대했다.',
      'fillerCount': 2,
      'silenceCount': 1,
      'highlightQuote': '(가짜) 여보세요, 주문할게요.',
      'highlightContext': 'USE_FAKE_LLM 데모 데이터',
    });
  }
}
