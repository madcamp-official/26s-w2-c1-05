import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 5. 관전 모드 (비밀 정보 미포함 스트림)
class BattleWatchScreen extends StatelessWidget {
  const BattleWatchScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Battle Watch ($roomId)');
}
