import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 2.2 브리핑 (시나리오·클리어 조건·제한 시간)
class BossBriefingScreen extends StatelessWidget {
  const BossBriefingScreen({super.key, required this.bossId});

  final String bossId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Boss Briefing ($bossId)');
}
