import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 3.5 배틀 결과 (판정 / 비밀 공개 / 리포트 탭)
class BattleResultScreen extends StatelessWidget {
  const BattleResultScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Battle Result ($roomId)');
}
