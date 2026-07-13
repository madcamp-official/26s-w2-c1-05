import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/call/call_session.dart';
import '../../core/call/llm_tasks.dart';
import '../../core/call/session_store.dart';
import '../../core/data/bosses.dart';
import '../../services/game_server_client.dart';
import '../../services/llm_factory.dart';
import '../../services/player_records.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.4 결과 + 리포트 (보스전) — 디자인 I 섹션 이식.
/// 탭A 판정(VerdictBanner+ScoreRing+조건 O/X) / 탭B 리포트(스탯·이렇게 말했다면·하이라이트).
/// 최종 심판(Gemini) 실데이터 사용. 침묵 타임라인·전달 체크는 데이터 없음 → 미표시.
/// 심판 완료 시 서버에 판 종료 보고(트랜스크립트+심판, Phase 2 §4) — best-effort,
/// 서버가 boss_progress(격파·최고점)를 자동 갱신한다.
class BossResultScreen extends StatefulWidget {
  const BossResultScreen({super.key, required this.bossId, required this.sessionId});

  final String bossId;
  final String sessionId;

  @override
  State<BossResultScreen> createState() => _BossResultScreenState();
}

class _BossResultScreenState extends State<BossResultScreen> {
  int _tab = 0; // 0 판정 / 1 리포트

  CallRecord? get _record => SessionStore.get(widget.sessionId);

  Future<JudgeResult> _judge(CallRecord record) {
    return record.judgeFuture ??= runFinalJudge(
      llm: createLlmClient(),
      boss: record.boss,
      transcript: record.transcript,
      endReason: record.endReason,
    ).then((judge) {
      _reportEnd(record, judge); // fire-and-forget — 화면 지연 없음
      return judge;
    });
  }

  /// 서버에 판 종료 보고. 실패해도 UI에 영향 없음 (best-effort).
  /// 성공 시에만 endReported=true — '다시 심판' 재시도 시 중복 INSERT 방지는
  /// 서버 단일 트랜잭션(실패 = 미저장)이라 재시도 안전.
  Future<void> _reportEnd(CallRecord record, JudgeResult judge) async {
    final serverId = record.serverSessionId;
    if (serverId == null || record.endReported) return;
    try {
      await GameServerClient().postJson('/sessions/$serverId/end', {
        'end_reason': switch (record.endReason) {
          CallEndReason.hangUp => 'hang_up',
          CallEndReason.timeOut => 'time_out',
          CallEndReason.silenceOverflow => 'silence',
        },
        'result': judge.cleared ? 'win' : 'lose',
        'score': judge.score,
        'judge': judge.toJson(),
        'transcript': [
          for (final u in record.transcript)
            {'speaker': u.speaker, 'text': u.text, 't_start_ms': u.tStartMs},
        ],
      });
      record.endReported = true;
      bumpRecordsVersion(); // 홈/도감/전적 재조회 신호
    } catch (_) {
      // 보고 실패 — 전적·도감엔 이번 판이 빠지지만 게임 진행엔 지장 없음.
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('세션 기록이 없어요', style: TextStyle(color: YbsColor.textSub)),
              const SizedBox(height: YbsSpace.s4),
              YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<JudgeResult>(
          future: _judge(record),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return _judging(record);
            if (snap.hasError || snap.data == null) return _judgeError(record);
            return _result(record, snap.data!);
          },
        ),
      ),
    );
  }

  Widget _judging(CallRecord record) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: YbsColor.gold400),
          const SizedBox(height: YbsSpace.s5),
          Text('${record.boss.name}와의 통화를 심판 중…',
              style: const TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s2),
          const Text('전체 통화 기록을 정밀 평가하고 있어요',
              style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)),
        ],
      ),
    );
  }

  Widget _judgeError(CallRecord record) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('심판 결과를 받지 못했어요', style: TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s4),
          YbsButton(label: '다시 심판', onTap: () => setState(() => record.judgeFuture = null)),
          const SizedBox(height: YbsSpace.s2),
          YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
        ],
      ),
    );
  }

  // ================================================================ result
  Widget _result(CallRecord record, JudgeResult judge) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
          child: Row(children: [
            Expanded(child: _tabButton('판정', 0)),
            const SizedBox(width: 6),
            Expanded(child: _tabButton('리포트', 1)),
          ]),
        ),
        Expanded(child: _tab == 0 ? _verdictTab(record, judge) : _reportTab(record, judge)),
        Padding(
          padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 30),
          child: _cta(record, judge),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? YbsColor.surfaceCardHover : Colors.transparent,
          border: Border.all(color: active ? YbsColor.borderStrong : YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: YbsType.sub,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? YbsColor.textHero : YbsColor.textSub)),
      ),
    );
  }

  // ---- 탭 A 판정 ----
  Widget _verdictTab(CallRecord record, JudgeResult judge) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 30),
          VerdictBanner(
            victory: judge.cleared,
            title: judge.cleared ? '격파!' : '아깝다!',
            subtitle: judge.verdictLine.isEmpty ? null : judge.verdictLine,
          ),
          const SizedBox(height: YbsSpace.s4),
          ScoreRing(score: judge.score, size: 110, label: '이번 점수'),
          const SizedBox(height: YbsSpace.s3),
          Text('${record.boss.name} · ${_endReasonLabel(record)}',
              style: const TextStyle(fontSize: 13, color: YbsColor.textSub)),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s6, YbsSpace.s5, YbsSpace.s4),
            child: Container(
              padding: const EdgeInsets.all(YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('달성 조건',
                      style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.textFaint)),
                  const SizedBox(height: YbsSpace.s3),
                  if (judge.conditions.isEmpty)
                    const Text('조건 판정 데이터가 비어 있어요.', style: TextStyle(color: YbsColor.textFaint)),
                  for (final c in judge.conditions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: YbsSpace.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 18,
                                child: Text(c.met ? 'O' : 'X',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: YbsType.numeric,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: c.met ? YbsColor.go400 : YbsColor.live400)),
                              ),
                              const SizedBox(width: YbsSpace.s2 + 2),
                              Expanded(
                                child: Text(c.text,
                                    style: TextStyle(fontSize: YbsType.sub, color: c.met ? YbsColor.textBody : YbsColor.textSub)),
                              ),
                            ],
                          ),
                          if (c.evidence.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 28, top: 2),
                              child: Text('「${c.evidence}」',
                                  style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textFaint)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 탭 B 리포트 ----
  Widget _reportTab(CallRecord record, JudgeResult judge) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s5),
      children: [
        Row(children: [
          Expanded(child: _statCard('군말 (어… 그…)', '${judge.fillerCount}회', YbsColor.amber400, judge.deliveryNote.isEmpty ? null : null)),
          const SizedBox(width: YbsSpace.s2 + 2),
          Expanded(child: _statCard('침묵 (2초+)', '${judge.silenceCount}회', YbsColor.live400, null)),
        ]),
        if (judge.deliveryNote.isNotEmpty) ...[
          const SizedBox(height: YbsSpace.s3 + 2),
          Container(
            padding: const EdgeInsets.all(YbsSpace.s4 - 2),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('말하기 습관'),
                const SizedBox(height: 6),
                Text(judge.deliveryNote, style: const TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
              ],
            ),
          ),
        ],
        const SizedBox(height: YbsSpace.s3 + 2),
        Container(
          padding: const EdgeInsets.all(YbsSpace.s4 - 2),
          decoration: BoxDecoration(
            color: YbsColor.gold400.withValues(alpha: 0.05),
            border: Border.all(color: YbsColor.gold500),
            borderRadius: BorderRadius.circular(YbsRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이렇게 말했다면',
                  style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.gold300)),
              const SizedBox(height: YbsSpace.s3),
              if (judge.improvements.isEmpty)
                const Text('개선 제안이 비어 있어요.', style: TextStyle(color: YbsColor.textFaint)),
              for (final imp in judge.improvements)
                Padding(
                  padding: const EdgeInsets.only(bottom: YbsSpace.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('「${imp.situation}」',
                          style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint, decoration: TextDecoration.lineThrough)),
                      const SizedBox(height: 4),
                      Text('→ 「${imp.better}」',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textBody)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (judge.oneLiner.isNotEmpty) ...[
          const SizedBox(height: YbsSpace.s3 + 2),
          Text('오늘의 한마디 — ${judge.oneLiner}',
              style: const TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
        ],
        if (judge.highlightQuote.isNotEmpty) ...[
          const SizedBox(height: YbsSpace.s3 + 2),
          HighlightCard(
            quote: judge.highlightQuote,
            context_: judge.highlightContext.isEmpty ? null : judge.highlightContext,
            score: judge.score,
            bossName: record.boss.name,
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: TextStyle(
          fontSize: YbsType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: YbsType.labelTracking(YbsType.micro) / 2,
          color: YbsColor.textFaint));

  Widget _statCard(String label, String value, Color color, String? note) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4 - 2),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: YbsColor.textFaint)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontFamily: YbsType.numeric, fontSize: 22, fontWeight: FontWeight.w600, height: 1.1, color: color)),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(fontSize: 11, color: YbsColor.textSub)),
            ],
          ],
        ),
      );

  String _endReasonLabel(CallRecord record) => switch (record.endReason) {
        CallEndReason.hangUp => '통화 종료',
        CallEndReason.timeOut => '시간 초과',
        CallEndReason.silenceOverflow => '침묵 누적',
      };

  // ---- CTA: 재도전 / 다음 보스 / 도감 ----
  Widget _cta(CallRecord record, JudgeResult judge) {
    final ids = [for (final b in bossesSeed) b.id];
    final idx = ids.indexOf(record.boss.id);
    final nextId = ids[(idx + 1) % ids.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YbsButton(
          label: judge.cleared ? '다음 보스에게 전화 걸기' : '재도전 — 이번엔 끝낸다',
          size: YbsButtonSize.lg,
          fullWidth: true,
          onTap: () => context.go(judge.cleared ? '/bosses/$nextId' : '/bosses/${record.boss.id}/call'),
        ),
        const SizedBox(height: YbsSpace.s2 + 2),
        Row(children: [
          Expanded(
            child: YbsButton(
              label: judge.cleared ? '재도전' : '다음 보스',
              variant: YbsButtonVariant.secondary,
              fullWidth: true,
              onTap: () => context.go(judge.cleared ? '/bosses/${record.boss.id}/call' : '/bosses/$nextId'),
            ),
          ),
          const SizedBox(width: YbsSpace.s2 + 2),
          Expanded(
            child: YbsButton(
              label: '도감',
              variant: YbsButtonVariant.ghost,
              fullWidth: true,
              onTap: () => context.go('/bosses'),
            ),
          ),
        ]),
      ],
    );
  }
}
