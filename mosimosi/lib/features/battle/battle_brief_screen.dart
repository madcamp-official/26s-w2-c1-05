import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 3.2 비공개 브리핑 ★프라이빗 — 비밀 목표·규정 카드는 자기 몫만 수신
class BattleBriefScreen extends StatelessWidget {
  const BattleBriefScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Battle Brief ($roomId)');
}
