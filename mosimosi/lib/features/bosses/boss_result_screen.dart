import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/call/llm_tasks.dart';
import '../../core/call/session_store.dart';
import '../../services/llm_factory.dart';
import '../../ui/theme.dart';

/// 2.4 결과 화면 — 탭A 판정(승패·점수·조건 O/X·근거 인용) / 탭B 리포트.
/// 최종 심판은 이 화면 진입 시 1회 실행 (Gemini, FSD 6.2).
class BossResultScreen extends StatefulWidget {
  const BossResultScreen({
    super.key,
    required this.bossId,
    required this.sessionId,
  });

  final String bossId;
  final String sessionId;

  @override
  State<BossResultScreen> createState() => _BossResultScreenState();
}

class _BossResultScreenState extends State<BossResultScreen> {
  CallRecord? get _record => SessionStore.get(widget.sessionId);

  Future<JudgeResult> _judge(CallRecord record) {
    return record.judgeFuture ??= runFinalJudge(
      llm: createLlmClient(),
      boss: record.boss,
      transcript: record.transcript,
      endReason: record.endReason,
    );
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
              TextButton(onPressed: () => context.go('/home'), child: const Text('홈으로')),
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
            if (snap.connectionState != ConnectionState.done) {
              return _judging(record);
            }
            if (snap.hasError || snap.data == null) {
              return _judgeError(record);
            }
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
          const Text('심판 결과를 받지 못했어요',
              style: TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s4),
          ElevatedButton(
            onPressed: () => setState(() => record.judgeFuture = null), // 재시도
            child: const Text('다시 심판'),
          ),
          TextButton(onPressed: () => context.go('/home'), child: const Text('홈으로')),
        ],
      ),
    );
  }

  Widget _result(CallRecord record, JudgeResult judge) {
    final accent = judge.cleared ? YbsColor.gold400 : YbsColor.live500;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: YbsSpace.s8),
          Text(judge.cleared ? 'WIN' : 'LOSE',
              style: TextStyle(
                fontFamily: YbsType.display,
                fontSize: YbsType.poster,
                height: YbsType.leadingTight,
                color: accent,
              )),
          const SizedBox(height: YbsSpace.s2),
          Text(record.boss.name, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s3),
          Text('${judge.score}점',
              style: const TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: YbsType.displaySize,
                  fontWeight: FontWeight.w600,
                  color: YbsColor.textHero)),
          if (judge.verdictLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(YbsSpace.s6, YbsSpace.s2, YbsSpace.s6, 0),
              child: Text(judge.verdictLine,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
            ),
          const SizedBox(height: YbsSpace.s4),
          TabBar(
            indicatorColor: accent,
            labelColor: YbsColor.textHero,
            unselectedLabelColor: YbsColor.textFaint,
            tabs: const [Tab(text: '판정'), Tab(text: '리포트')],
          ),
          Expanded(
            child: TabBarView(
              children: [_verdictTab(judge), _reportTab(judge)],
            ),
          ),
          _cta(record),
        ],
      ),
    );
  }

  Widget _verdictTab(JudgeResult judge) {
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        for (final c in judge.conditions)
          Container(
            margin: const EdgeInsets.only(bottom: YbsSpace.s3),
            padding: const EdgeInsets.all(YbsSpace.s4),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: c.met ? YbsColor.go600 : YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(c.met ? Icons.check_circle : Icons.cancel,
                        size: 18, color: c.met ? YbsColor.go400 : YbsColor.live400),
                    const SizedBox(width: YbsSpace.s2),
                    Expanded(
                      child: Text(c.text,
                          style: const TextStyle(
                              fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
                    ),
                  ],
                ),
                if (c.evidence.isNotEmpty) ...[
                  const SizedBox(height: YbsSpace.s2),
                  Text('“${c.evidence}”',
                      style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textFaint)),
                ],
              ],
            ),
          ),
        if (judge.conditions.isEmpty)
          const Text('조건 판정 데이터가 비어 있어요.', style: TextStyle(color: YbsColor.textFaint)),
      ],
    );
  }

  Widget _reportTab(JudgeResult judge) {
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        if (judge.oneLiner.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: YbsSpace.s4),
            padding: const EdgeInsets.all(YbsSpace.s4),
            decoration: BoxDecoration(
              color: YbsColor.gold400.withValues(alpha: 0.10),
              border: Border.all(color: YbsColor.gold500),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: Text('오늘의 한마디 — ${judge.oneLiner}',
                style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.gold300)),
          ),
        if (judge.deliveryNote.isNotEmpty) ...[
          const Text('말하기 습관',
              style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          Text(judge.deliveryNote,
              style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s5),
        ],
        const Text('이렇게 말했다면',
            style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
        const SizedBox(height: YbsSpace.s2),
        for (final imp in judge.improvements)
          Container(
            margin: const EdgeInsets.only(bottom: YbsSpace.s3),
            padding: const EdgeInsets.all(YbsSpace.s4),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(imp.situation, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                const SizedBox(height: YbsSpace.s1),
                Text('→ ${imp.better}',
                    style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.go300)),
              ],
            ),
          ),
        if (judge.improvements.isEmpty)
          const Text('개선 제안이 비어 있어요.', style: TextStyle(color: YbsColor.textFaint)),
      ],
    );
  }

  Widget _cta(CallRecord record) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, YbsSpace.s5),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: YbsColor.go500,
                foregroundColor: YbsColor.textOnGo,
                minimumSize: const Size.fromHeight(YbsSpace.hitMin + 8),
              ),
              // 재도전은 브리핑 스킵 (IA F2)
              onPressed: () => context.go('/bosses/${record.boss.id}/call'),
              child: const Text('다시 도전', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: YbsSpace.s3),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: YbsColor.textBody,
                side: const BorderSide(color: YbsColor.borderStrong),
                minimumSize: const Size.fromHeight(YbsSpace.hitMin + 8),
              ),
              onPressed: () => context.go('/home'),
              child: const Text('홈으로'),
            ),
          ),
        ],
      ),
    );
  }
}
