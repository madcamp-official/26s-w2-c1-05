import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';

/// GNB 셸 (IA §4): 홈 / 도감 / 전적 3개 목적지.
/// 모바일 = 하단 탭바, 데스크톱 = 좌측 사이드 레일 (IA 미해결 #1 → 레일 선택).
/// 통화·배틀·설정·스파이크는 셸 밖 풀스크린 라우트.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: YbsColor.ink900,
              indicatorColor: YbsColor.go500.withValues(alpha: 0.15),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              selectedLabelTextStyle:
                  const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go400),
              unselectedLabelTextStyle:
                  const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint),
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.home_outlined, color: YbsColor.textFaint),
                    selectedIcon: Icon(Icons.home, color: YbsColor.go400),
                    label: Text('홈')),
                NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined, color: YbsColor.textFaint),
                    selectedIcon: Icon(Icons.menu_book, color: YbsColor.go400),
                    label: Text('도감')),
                NavigationRailDestination(
                    icon: Icon(Icons.insights_outlined, color: YbsColor.textFaint),
                    selectedIcon: Icon(Icons.insights, color: YbsColor.go400),
                    label: Text('전적')),
              ],
            ),
            const VerticalDivider(width: 1, color: YbsColor.borderSoft),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: YbsColor.ink900,
        indicatorColor: YbsColor.go500.withValues(alpha: 0.15),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined, color: YbsColor.textFaint),
              selectedIcon: Icon(Icons.home, color: YbsColor.go400),
              label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: YbsColor.textFaint),
              selectedIcon: Icon(Icons.menu_book, color: YbsColor.go400),
              label: '도감'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined, color: YbsColor.textFaint),
              selectedIcon: Icon(Icons.insights, color: YbsColor.go400),
              label: '전적'),
        ],
      ),
    );
  }
}

/// 탭 화면 공통 헤더 — 타이틀 + 우상단 프로필(→설정) (IA §4).
class YbsHeader extends StatelessWidget {
  const YbsHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s3, YbsSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: YbsType.display,
                    fontSize: YbsType.title,
                    color: YbsColor.textHero)),
          ),
          trailing ??
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.account_circle_outlined, color: YbsColor.textSub, size: 28),
              ),
        ],
      ),
    );
  }
}
