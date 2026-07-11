import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 4. 내 전적 — 4.1 대시보드 요약 + 4.2 전적 목록 (+랭킹 진입).
/// 전부 목 데이터 — DB/전적 API는 P1.5.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0; // 0 전체 / 1 보스전 / 2 배틀

  static const _sessions = [
    (_Kind.boss, '환불 불가 3연벙 상담원', true, 82, '오늘 21:04'),
    (_Kind.battle, 'vs 환불전사_수원 (상담원)', false, 46, '오늘 20:31'),
    (_Kind.boss, '따발총 치과 접수원', false, 68, '어제 23:12'),
    (_Kind.boss, '무던한 치킨집 사장님', true, 91, '어제 22:40'),
    (_Kind.battle, 'vs 콜포비아극복러 (민원인)', true, 61, '7/9 21:55'),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final list = [
      for (final s in _sessions)
        if (_filter == 0 || (_filter == 1) == (s.$1 == _Kind.boss)) s,
    ];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YbsHeader(
                title: '내 전적',
                trailing: TextButton.icon(
                  onPressed: () => context.go('/ranking'),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18, color: YbsColor.gold400),
                  label: const Text('랭킹', style: TextStyle(color: YbsColor.gold400)),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(desktop ? YbsLayout.screenPadDesktop : YbsSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dashboard(desktop),
                    const SizedBox(height: YbsSpace.s6),
                    _filterChips(),
                    const SizedBox(height: YbsSpace.s3),
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

  // ---- 4.1 대시보드 (점수 추이 목 스파크 + 스탯 타일) ----
  Widget _dashboard(bool desktop) {
    const trend = [42, 55, 48, 68, 61, 74, 82]; // 목 점수 추이
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in trend)
                  Expanded(
                    child: Container(
                      height: 64 * v / 100,
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
            stat('74', '평균 점수', YbsColor.textHero),
            const SizedBox(width: YbsSpace.s2),
            stat('-12%', '군말(필러)', YbsColor.go400),
            const SizedBox(width: YbsSpace.s2),
            stat('-8초', '평균 침묵', YbsColor.go400),
          ]),
        ],
      ),
    );
  }

  Widget _filterChips() {
    const labels = ['전체', '보스전', '배틀'];
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

  Widget _sessionTile((_Kind, String, bool, int, String) s) {
    final (kind, title, win, score, playedAt) = s;
    final accent = win ? YbsColor.go400 : YbsColor.live400;
    return GestureDetector(
      onTap: () => context.go('/history/mock'),
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
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                  Text('${kind == _Kind.boss ? '보스전' : '배틀'} · $playedAt',
                      style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                ],
              ),
            ),
            Text('$score점',
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyMd, fontWeight: FontWeight.w600, color: YbsColor.textBody)),
            const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
          ],
        ),
      ),
    );
  }
}

enum _Kind { boss, battle }
