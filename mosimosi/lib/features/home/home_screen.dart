import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 1. 홈 (게임 로비, IA §3) — 진입 즉시 보스전/배틀이 지배적.
/// 이어하기·오늘의 전적은 영속화 전이라 목 데이터.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final modeCards = [
      _ModeCard(
        title: '전화 보스전',
        subtitle: '전설의 진상 도감 — AI 보스와 1:1 통화',
        icon: Icons.sports_kabaddi,
        accent: YbsColor.live500,
        badge: '싱글',
        onTap: () => context.go('/bosses'),
      ),
      _ModeCard(
        title: '전화 배틀',
        subtitle: '실시간 유저 대전 — 민원인 vs 상담원',
        icon: Icons.bolt,
        accent: YbsColor.go500,
        badge: '멀티',
        onTap: () => context.push('/battle'),
      ),
    ];
    final sideCards = [_continueCard(context), const SizedBox(height: YbsSpace.s4), _todaySummary()];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const YbsHeader(title: '여보세요'),
              Padding(
                padding: EdgeInsets.all(desktop ? YbsLayout.screenPadDesktop : YbsSpace.s5),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(children: [
                              modeCards[0],
                              const SizedBox(height: YbsSpace.s4),
                              modeCards[1],
                            ]),
                          ),
                          const SizedBox(width: YbsSpace.s6),
                          Expanded(flex: 2, child: Column(children: sideCards)),
                        ],
                      )
                    : Column(children: [
                        modeCards[0],
                        const SizedBox(height: YbsSpace.s4),
                        modeCards[1],
                        const SizedBox(height: YbsSpace.s6),
                        ...sideCards,
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이어하기 카드 (IA 미해결 #6 — 이어하기 채택). 목: 마지막 도전 = 치과.
  Widget _continueCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/bosses/dental'),
      child: Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.sky400, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('따',
                  style: TextStyle(fontFamily: YbsType.display, fontSize: 22, height: 1, color: YbsColor.sky400)),
            ),
            const SizedBox(width: YbsSpace.s4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이어하기', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textFaint)),
                  Text('따발총 치과 접수원', style: TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                  Text('지난 도전 — 68점, 조건 1/2', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: YbsColor.textFaint),
          ],
        ),
      ),
    );
  }

  /// 오늘의 전적 요약 (목).
  Widget _todaySummary() {
    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: YbsSpace.s3),
            decoration: BoxDecoration(
              color: YbsColor.surfaceInset,
              borderRadius: BorderRadius.circular(YbsRadius.sm),
            ),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyLg, fontWeight: FontWeight.w600, color: YbsColor.textHero)),
                Text(label, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
              ],
            ),
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
          const Text('오늘의 전적', style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s3),
          Row(children: [
            stat('2판', '플레이'),
            const SizedBox(width: YbsSpace.s2),
            stat('50%', '승률'),
            const SizedBox(width: YbsSpace.s2),
            stat('12분', '통화 연습'),
          ]),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(YbsSpace.s5),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: accent.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(YbsRadius.lg),
          boxShadow: [
            ...YbsShadow.card,
            BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 24),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [accent.withValues(alpha: 0.25), Colors.transparent]),
                border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
              ),
              child: Icon(icon, size: 30, color: accent),
            ),
            const SizedBox(width: YbsSpace.s5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.textHero)),
                    const SizedBox(width: YbsSpace.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s2, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(YbsRadius.full),
                      ),
                      child: Text(badge,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
                    ),
                  ]),
                  const SizedBox(height: YbsSpace.s1),
                  Text(subtitle, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }
}
