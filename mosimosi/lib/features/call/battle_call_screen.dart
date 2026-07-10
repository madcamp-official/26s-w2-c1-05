import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 3.3 배틀 통화 화면 ★막다른 방
class BattleCallScreen extends StatelessWidget {
  const BattleCallScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Battle Call ($roomId)');
}
