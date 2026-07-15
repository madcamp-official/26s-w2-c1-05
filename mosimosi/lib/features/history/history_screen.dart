import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/bosses.dart';
import '../../services/player_records.dart';
import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 4. 내 전적 — 4.1 대시보드 요약 + 4.2 전적 목록.
/// GET /users/{id}/sessions 실데이터 (Phase 2 §5). 점수 추이·평균·승률·판수는
/// 받은 목록에서 클라 계산. 군말/침묵 평균은 세션별 judge 파싱 필요 → P2.5.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0; // 0 전체 / 1 AI 대전 / 2 배틀

  /// null = 로딩 중. _error와 함께 상태 구분.
  List<SessionRecord>? _sessions;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    recordsVersion.addListener(_load); // 판 종료 보고 후 재조회 (셸 탭 유지 대응)
  }

  @override
  void dispose() {
    recordsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sessions = await fetchSessions(limit: 50);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted && _sessions == null) setState(() => _error = true);
    }
  }

  String _title(SessionRecord s) {
    if (s.mode == 'battle') return '실전 배틀';
    final boss =
        bossesSeed.where((b) => b.id == s.bossId).map((b) => b.name).firstOrNull;
    return boss ?? s.bossId ?? 'AI 대전';
  }

  String _playedAt(SessionRecord s) {
    final t = s.startedAt;
    final now = DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (day == today) return '오늘 $hm';
    if (day == today.subtract(const Duration(days: 1))) return '어제 $hm';
    return '${t.month}/${t.day} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final sessions = _sessions ?? const <SessionRecord>[];
    final list = [
      for (final s in sessions)
        if (_filter == 0 || (_filter == 1) == (s.mode == 'boss')) s,
    ];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const YbsHeader(title: '내 전적', trailing: SizedBox.shrink()),
              Padding(
                padding: EdgeInsets.all(desktop ? YbsLayout.screenPadDesktop : YbsSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dashboard(desktop, sessions),
                    const SizedBox(height: YbsSpace.s6),
                    _filterChips(),
                    const SizedBox(height: YbsSpace.s3),
                    if (_sessions == null && !_error)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: YbsSpace.s6),
                        child: Center(child: CircularProgressIndicator(color: YbsColor.go400)),
                      )
                    else if (_error)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: YbsSpace.s6),
                        child: Column(children: [
                          const Text('기록을 불러오지 못했어요',
                              style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
                          const SizedBox(height: YbsSpace.s3),
                          TextButton(
                              onPressed: _load,
                              child: const Text('다시 시도', style: TextStyle(color: YbsColor.go400))),
                        ]),
                      )
                    else if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: YbsSpace.s6),
                        child: Center(
                          child: Text('아직 기록이 없어요 — 첫 보스에게 전화를 걸어보세요',
                              style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)),
                        ),
                      )
                    else
                      for (final s in list) _sessionTile(s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 4.1 대시보드 (점수 추이 + 스탯 타일 — 세션 목록에서 계산) ----
  Widget _dashboard(bool desktop, List<SessionRecord> sessions) {
    final scored = [for (final s in sessions) if (s.score != null) s.score!];
    // 서버는 최신순 → 추이는 시간순으로 뒤집어 최근 7판.
    final trend = scored.take(7).toList().reversed.toList();
    final avg = scored.isEmpty
        ? '–'
        : '${(scored.reduce((a, b) => a + b) / scored.length).round()}';
    final finished = sessions.where((s) => s.result != null).length;
    final winRate = finished == 0
        ? '–'
        : '${(sessions.where((s) => s.win).length * 100 / finished).round()}%';
    Widget stat(String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: YbsSpace.s3),
            decoration: BoxDecoration(color: YbsColor.surfaceInset, borderRadius: BorderRadius.circular(YbsRadius.sm)),
            child: Column(children: [
              Text(value, style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyLg, fontWeight: FontWeight.w600, color: color)),
              Text(label, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 점수 추이', style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s3),
          SizedBox(
            height: 64,
            child: trend.isEmpty
                ? const Center(
                    child: Text('점수가 쌓이면 추이가 보여요',
                        style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final v in trend)
                        Expanded(
                          child: Container(
                            height: 64 * v.clamp(0, 100) / 100,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: v == trend.last ? YbsColor.go500 : YbsColor.ink600,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: YbsSpace.s4),
          Row(children: [
            stat(avg, '평균 점수', YbsColor.textHero),
            const SizedBox(width: YbsSpace.s2),
            stat(winRate, '승률', YbsColor.go400),
            const SizedBox(width: YbsSpace.s2),
            stat(_sessions == null ? '–' : '${sessions.length}', '총 판수', YbsColor.textHero),
          ]),
        ],
      ),
    );
  }

  Widget _filterChips() {
    const labels = ['전체', 'AI 대전', '실전 배틀'];
    return Row(children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(right: YbsSpace.s2),
          child: GestureDetector(
            onTap: () => setState(() => _filter = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s2),
              decoration: BoxDecoration(
                color: _filter == i ? YbsColor.go500.withValues(alpha: 0.12) : YbsColor.surfaceCard,
                border: Border.all(color: _filter == i ? YbsColor.go600 : YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: YbsType.micro,
                      fontWeight: FontWeight.w700,
                      color: _filter == i ? YbsColor.go300 : YbsColor.textSub)),
            ),
          ),
        ),
    ]);
  }

  Widget _sessionTile(SessionRecord s) {
    final win = s.win;
    final accent = win ? YbsColor.go400 : YbsColor.live400;
    return GestureDetector(
      onTap: () => context.go('/history/${s.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: YbsSpace.s3),
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        child: Row(
          children: [
            Text(win ? 'WIN' : 'LOSE',
                style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.sub, color: accent)),
            const SizedBox(width: YbsSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                  Text('${s.mode == 'boss' ? 'AI 대전' : '실전 배틀'} · ${_playedAt(s)}',
                      style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                ],
              ),
            ),
            Text(s.score == null ? '—' : '${s.score}점',
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyMd, fontWeight: FontWeight.w600, color: YbsColor.textBody)),
            const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
          ],
        ),
      ),
    );
  }
}
