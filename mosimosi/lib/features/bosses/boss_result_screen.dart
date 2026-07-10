import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 2.4 결과 화면 (판정 / 리포트 탭)
class BossResultScreen extends StatelessWidget {
  const BossResultScreen({
    super.key,
    required this.bossId,
    required this.sessionId,
  });

  final String bossId;
  final String sessionId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Boss Result ($bossId / $sessionId)');
}
