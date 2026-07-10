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

/// IA §8 라우트 구조. 데스크톱/모바일 동일 라우트, 레이아웃만 폼팩터 분기.
/// TODO: 통화 라우트 직접 진입 시 세션 유효성 검사 → 무효면 브리핑 리다이렉트.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/bosses',
      builder: (context, state) => const BossListScreen(),
    ),
    GoRoute(
      path: '/bosses/:id',
      builder: (context, state) =>
          BossBriefingScreen(bossId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/bosses/:id/call',
      builder: (context, state) =>
          BossCallScreen(bossId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/bosses/:id/result/:sessionId',
      builder: (context, state) => BossResultScreen(
        bossId: state.pathParameters['id']!,
        sessionId: state.pathParameters['sessionId']!,
      ),
    ),
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
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/history/:sessionId',
      builder: (context, state) =>
          SessionDetailScreen(sessionId: state.pathParameters['sessionId']!),
    ),
    GoRoute(
      path: '/ranking',
      builder: (context, state) => const RankingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
