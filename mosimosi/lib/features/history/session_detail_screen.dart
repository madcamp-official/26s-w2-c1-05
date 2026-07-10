import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 4.2.1 판 상세 (트랜스크립트 리플레이 + 리포트)
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(name: 'Session Detail ($sessionId)');
}
