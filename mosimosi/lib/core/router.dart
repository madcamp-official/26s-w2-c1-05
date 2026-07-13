import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/battle/battle_brief_screen.dart';
import '../features/battle/battle_matching_screen.dart';
import '../features/battle/battle_result_screen.dart';
import '../features/battle/battle_watch_screen.dart';
import '../features/bosses/boss_briefing_screen.dart';
import '../features/bosses/boss_list_screen.dart';
import '../features/bosses/boss_result_screen.dart';
import '../features/call/battle_call_screen.dart';
import '../features/call/boss_call_screen.dart';
import '../features/history/history_screen.dart';
import '../features/history/ranking_screen.dart';
import '../features/history/session_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/spike/spike_screen.dart';

/// IA §8 라우트 구조 + §4 GNB: 홈/도감/전적은 셸(탭) 안, 통화·배틀·설정은
/// 풀스크린. GNB 숨김 화면(2.3/3.x)은 rootNavigatorKey로 셸 밖에 띄운다.
/// TODO: 통화 라우트 직접 진입 시 세션 유효성 검사 → 무효면 브리핑 리다이렉트.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// main()이 LocalStore 로드 후 첫 화면을 정해 호출한다
/// (user_id 있으면 '/home', 없으면 '/onboarding' — Phase 2 §2 온보딩 스킵).
GoRouter buildRouter({required String initialLocation}) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/bosses',
            builder: (context, state) => const BossListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    BossBriefingScreen(bossId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'call',
                    parentNavigatorKey: _rootNavigatorKey, // 막다른 방 — GNB 숨김
                    builder: (context, state) =>
                        BossCallScreen(bossId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'result/:sessionId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => BossResultScreen(
                      bossId: state.pathParameters['id']!,
                      sessionId: state.pathParameters['sessionId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
            routes: [
              GoRoute(
                path: ':sessionId',
                builder: (context, state) => SessionDetailScreen(
                    sessionId: state.pathParameters['sessionId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/ranking',
            builder: (context, state) => const RankingScreen(),
          ),
        ]),
      ],
    ),
    // ---- 셸 밖 풀스크린: 배틀(홈 CTA 진입, IA §4) ----
    GoRoute(
      path: '/battle',
      builder: (context, state) => const BattleMatchingScreen(),
    ),
    GoRoute(
      path: '/battle/:roomId/brief',
      builder: (context, state) =>
          BattleBriefScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/battle/:roomId/call',
      builder: (context, state) =>
          BattleCallScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/battle/:roomId/result',
      builder: (context, state) =>
          BattleResultScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/battle/:roomId/watch',
      builder: (context, state) =>
          BattleWatchScreen(roomId: state.pathParameters['roomId']!),
    ),
    // ---- 설정(프로필 → 시트, GNB 미노출) / 개발용 스파이크 ----
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/spike',
      builder: (context, state) => const SpikeScreen(),
    ),
  ],
);
