import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 1. 홈 (게임 로비)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Home'),
            const SizedBox(height: 24),
            // Day 1 스파이크 진입 (임시).
            ElevatedButton(
              onPressed: () => context.go('/spike'),
              child: const Text('Day 1 스파이크 열기'),
            ),
            const SizedBox(height: 12),
            // 통화 화면 디자인 시안 진입 (임시).
            ElevatedButton(
              onPressed: () => context.go('/bosses/8/call'),
              child: const Text('보스 통화 화면 (디자인)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/battle/demo/call'),
              child: const Text('배틀 통화 화면 (디자인)'),
            ),
          ],
        ),
      ),
    );
  }
}
