import 'package:flutter/material.dart';

import '../../core/call/llm_tasks.dart';
import '../../core/data/bosses.dart';
import '../../services/player_records.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 4.2.1 판 상세 — 트랜스크립트 리플레이 + 당시 리포트.
/// GET /users/me/sessions/{id} 실데이터 사용. 판정 실패·중도 종료 판은
/// judge가 없을 수 있어 화면이 반드시 이를 대비한다.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId, this.fetcher = fetchSessionDetail});

  final String sessionId;

  /// 테스트에서 네트워크 없이 주입할 수 있도록 분리 (CloudTtsEngine과 동일 패턴).
  final Future<SessionDetail> Function(String) fetcher;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<SessionDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher(widget.sessionId);
  }

  String _title(SessionDetail d) {
    if (d.mode == 'battle') return '전화 배틀';
    final boss = bossesSeed.where((b) => b.id == d.bossId).map((b) => b.name).firstOrNull;
    return boss ?? d.bossId ?? '보스전';
  }

  String _playedAt(SessionDetail d) {
    final t = d.startedAt;
    final now = DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final date = day == today
        ? '오늘'
        : day == today.subtract(const Duration(days: 1))
            ? '어제'
            : '${t.month}/${t.day}';
    final duration = d.endedAt == null
        ? ''
        : ' · ${_mmss(d.endedAt!.difference(d.startedAt).inMilliseconds)}';
    return '$date $hm$duration';
  }

  String _mmss(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('판 상세', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.bodyLg)),
      ),
      body: SafeArea(
        child: FutureBuilder<SessionDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: YbsColor.go400));
            }
            if (snap.hasError || snap.data == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('전적을 불러오지 못했어요', style: TextStyle(color: YbsColor.textSub)),
                    const SizedBox(height: YbsSpace.s3),
                    TextButton(
                      onPressed: () => setState(() => _future = widget.fetcher(widget.sessionId)),
                      child: const Text('다시 시도', style: TextStyle(color: YbsColor.go400)),
                    ),
                  ],
                ),
              );
            }
            return _body(snap.data!);
          },
        ),
      ),
    );
  }

  Widget _body(SessionDetail d) {
    final judge = d.judge == null ? null : JudgeResult.fromJson(d.judge!);
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        _summaryHeader(d, judge),
        const SizedBox(height: YbsSpace.s6),
        const Text('트랜스크립트 리플레이',
            style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
        const SizedBox(height: YbsSpace.s3),
        if (d.transcript.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: YbsSpace.s4),
            child: Text('저장된 대화 기록이 없어요', style: TextStyle(color: YbsColor.textFaint)),
          )
        else
          for (final l in d.transcript)
            Padding(
              padding: const EdgeInsets.only(bottom: YbsSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(_mmss(l.tStartMs),
                          style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, color: YbsColor.textFaint)),
                    ),
                  ),
                  Expanded(
                    child: LiveCaption(
                      speaker: l.speaker == 'boss' ? CaptionSpeaker.boss : CaptionSpeaker.player,
                      name: l.speaker == 'boss' ? _title(d) : '나',
                      text: l.text,
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: YbsSpace.s4),
        const Text('당시 리포트',
            style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
        const SizedBox(height: YbsSpace.s3),
        if (judge == null)
          Container(
            padding: const EdgeInsets.all(YbsSpace.s4),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: const Text('이 판은 판정 리포트가 저장되지 않았어요 (중도 종료 등).',
                style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)),
          )
        else ...[
          if (judge.oneLiner.isNotEmpty)
            Container(
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
            const SizedBox(height: YbsSpace.s3),
            Container(
              padding: const EdgeInsets.all(YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('말하기 습관 · 군말 ${judge.fillerCount}회 · 침묵 ${judge.silenceCount}회',
                      style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                  const SizedBox(height: YbsSpace.s1),
                  Text(judge.deliveryNote, style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textBody)),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _summaryHeader(SessionDetail d, JudgeResult? judge) {
    final resultLabel = d.result == null ? '진행중' : (d.win ? 'WIN' : 'LOSE');
    final resultColor = d.result == null
        ? YbsColor.textFaint
        : (d.win ? YbsColor.gold400 : YbsColor.live400);
    return Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.gold500),
        borderRadius: BorderRadius.circular(YbsRadius.lg),
      ),
      child: Row(
        children: [
          Text(resultLabel, style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: resultColor)),
          const SizedBox(width: YbsSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(d),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                Text('${d.mode == 'boss' ? '보스전' : '배틀'} · ${_playedAt(d)}',
                    style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
              ],
            ),
          ),
          Text(d.score == null ? '—' : '${d.score}점',
              style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.title, fontWeight: FontWeight.w600, color: YbsColor.textHero)),
        ],
      ),
    );
  }
}
