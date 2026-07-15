/// Gemini 담당 태스크 (FSD 6.2/6.3): 시나리오 변수 생성 + 최종 심판.
///
/// 결정: 최종 심판과 리포트를 1회 호출로 통합 (FSD는 판당 2회로 분리하지만
/// 스키마 하나로 충분해 지연·비용 절반. 필요 시 분리 용이).
library;

import 'dart:convert';

import '../../services/llm_client.dart';
import '../models/boss.dart';
import 'call_session.dart';

/// 판 시작 시 랜덤 변수 2~3개 생성 (FSD 3.1.3 리플레이성). 실패 시 빈 리스트.
Future<List<String>> generateScenarioVariables({
  required LlmClient llm,
  required Boss boss,
}) async {
  final prompt = '''
전화 훈련 게임의 AI 대전에 리플레이성을 주는 상황 변수를 만들어라.
보스: ${boss.name}
시나리오: ${boss.scenario}

변수는 보스가 통화 중 자연스럽게 드러낼 수 있는 구체적 사실 2~3개다
(예: 품절 메뉴, 진행 중인 이벤트, 예약이 꽉 찬 시간대, 신규 규정).
JSON만 출력: {"variables": ["...", "..."]}''';

  final raw = await llm.chatStream(
    [LlmMessage(role: 'user', content: prompt)],
    task: 'scenario',
    temperature: 1.0,
    maxOutputTokens: 256,
  ).join();
  final json = _extractJson(raw);
  final list = json['variables'];
  if (list is! List) return const [];
  return list.whereType<String>().toList();
}

/// 최종 심판 결과 (판정 + 리포트, FSD 6.3 최종 심판 / 7.1 리포트).
class JudgeResult {
  const JudgeResult({
    required this.cleared,
    required this.score,
    required this.verdictLine,
    required this.conditions,
    required this.improvements,
    required this.deliveryNote,
    required this.oneLiner,
    required this.fillerCount,
    required this.silenceCount,
    required this.highlightQuote,
    required this.highlightContext,
  });

  final bool cleared;
  final int score; // 0~100
  final String verdictLine; // 한 줄 판정 근거
  final List<ConditionResult> conditions;
  final List<Improvement> improvements; // "이렇게 말했다면" 2~3개
  final String deliveryNote; // 더듬은 구간/필러/침묵 코멘트
  final String oneLiner; // 오늘의 한마디
  final int fillerCount; // 군말("어…","그…") 횟수
  final int silenceCount; // 2초+ 침묵 횟수
  final String highlightQuote; // 하이라이트 카드용 플레이어 명대사
  final String highlightContext; // 그 순간 설명

  factory JudgeResult.fromJson(Map<String, dynamic> j) => JudgeResult(
        cleared: j['cleared'] == true,
        score: (j['score'] as num?)?.round().clamp(0, 100) ?? 0,
        verdictLine: j['verdictLine'] as String? ?? '',
        conditions: [
          for (final c in (j['conditions'] as List? ?? const []))
            if (c is Map<String, dynamic>) ConditionResult.fromJson(c),
        ],
        improvements: [
          for (final i in (j['improvements'] as List? ?? const []))
            if (i is Map<String, dynamic>) Improvement.fromJson(i),
        ],
        deliveryNote: j['deliveryNote'] as String? ?? '',
        oneLiner: j['oneLiner'] as String? ?? '',
        fillerCount: (j['fillerCount'] as num?)?.round() ?? 0,
        silenceCount: (j['silenceCount'] as num?)?.round() ?? 0,
        highlightQuote: j['highlightQuote'] as String? ?? '',
        highlightContext: j['highlightContext'] as String? ?? '',
      );

  /// 서버 judge(jsonb) 저장용 — fromJson과 같은 키 (POST /sessions/{id}/end).
  Map<String, dynamic> toJson() => {
        'cleared': cleared,
        'score': score,
        'verdictLine': verdictLine,
        'conditions': [
          for (final c in conditions)
            {'text': c.text, 'met': c.met, 'evidence': c.evidence},
        ],
        'improvements': [
          for (final i in improvements)
            {'situation': i.situation, 'better': i.better},
        ],
        'deliveryNote': deliveryNote,
        'oneLiner': oneLiner,
        'fillerCount': fillerCount,
        'silenceCount': silenceCount,
        'highlightQuote': highlightQuote,
        'highlightContext': highlightContext,
      };
}

class ConditionResult {
  const ConditionResult({required this.text, required this.met, required this.evidence});
  final String text;
  final bool met;
  final String evidence; // 근거 대사 인용 (판정 신뢰 장치, FSD 10)

  factory ConditionResult.fromJson(Map<String, dynamic> j) => ConditionResult(
        text: j['text'] as String? ?? '',
        met: j['met'] == true,
        evidence: j['evidence'] as String? ?? '',
      );
}

class Improvement {
  const Improvement({required this.situation, required this.better});
  final String situation; // 어떤 순간이었는지
  final String better; // 이렇게 말했다면

  factory Improvement.fromJson(Map<String, dynamic> j) => Improvement(
        situation: j['situation'] as String? ?? '',
        better: j['better'] as String? ?? '',
      );
}

/// 종료 후 전체 트랜스크립트 정밀 심판 (FSD 4.4 — 최종 승패는 여기서 결정).
Future<JudgeResult> runFinalJudge({
  required LlmClient llm,
  required Boss boss,
  required List<Utterance> transcript,
  required CallEndReason endReason,
}) async {
  String mmss(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  final log = transcript
      .map((u) => '(${mmss(u.tStartMs)}) ${u.speaker == 'user' ? '플레이어' : '보스'}: ${u.text}')
      .join('\n');
  final conds = [
    for (var i = 0; i < boss.clearConditions.length; i++) '${i + 1}. ${boss.clearConditions[i]}',
  ].join('\n');
  final reason = switch (endReason) {
    CallEndReason.hangUp => '플레이어가 통화를 종료함',
    CallEndReason.timeOut => '제한 시간 초과',
    CallEndReason.silenceOverflow => '침묵 누적으로 보스 인내심 소진',
    CallEndReason.bossHangUp => '상대가 용건을 마무리하고 통화를 끊음',
  };

  final prompt = '''
너는 전화 통화 훈련 게임 '여보세요'의 최종 심판이다. 아래 통화를 평가해 JSON만 출력해라.

[보스] ${boss.name} — ${boss.scenario}
[클리어 조건]
$conds
[종료 사유] $reason
[통화 기록]
$log

평가 규칙:
- 각 클리어 조건의 달성 여부를 반드시 통화 기록의 실제 대사 인용(evidence)으로 뒷받침해라.
- cleared는 조건 전부 달성 시에만 true.
- improvements는 플레이어가 실제로 서툴렀던 순간 2~3개를 골라, situation에는 실제 발화(또는 침묵)를,
  better에는 "이렇게 말했다면" 대안 문장을 제시해라.
- deliveryNote에는 더듬음·군말·침묵 등 말하기 습관을 짧게 코멘트해라.
- fillerCount는 플레이어 발화의 군말("어…", "그…", "음…") 횟수, silenceCount는 눈에 띄는 침묵 횟수 추정치.
- highlightQuote는 플레이어의 가장 결정적인 실제 대사 1개, highlightContext는 그 순간을 한 줄로.
- oneLiner는 리포트 맨 위에 붙는 위트 있는 한 줄 (상황을 놀리되 플레이어를 놀리지 마라).

출력 JSON 스키마 (다른 텍스트 금지):
{"cleared": bool, "score": 0-100, "verdictLine": "한 줄 판정 근거",
 "conditions": [{"text": "조건", "met": bool, "evidence": "인용 대사"}],
 "improvements": [{"situation": "실제 발화", "better": "이렇게 말했다면"}],
 "deliveryNote": "말하기 습관 코멘트", "oneLiner": "오늘의 한마디",
 "fillerCount": int, "silenceCount": int,
 "highlightQuote": "플레이어 명대사", "highlightContext": "그 순간 설명"}''';

  final raw = await llm.chatStream(
    [LlmMessage(role: 'user', content: prompt)],
    task: 'final_judge',
    temperature: 0.2,
    maxOutputTokens: 1024,
  ).join();
  return JudgeResult.fromJson(_extractJson(raw));
}

/// 응답에서 JSON 본문 추출 (```json 펜스·잡담 방어).
Map<String, dynamic> _extractJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  try {
    final decoded = jsonDecode(raw.substring(start, end + 1));
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}
