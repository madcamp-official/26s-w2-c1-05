import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 2.3 통화 화면 (싱글) ★막다른 방 — 통화 중 GNB 숨김, 이탈은 끊기만
class BossCallScreen extends StatelessWidget {
  const BossCallScreen({super.key, required this.bossId});

  final String bossId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Boss Call ($bossId)');
}
