import 'package:flutter/material.dart';

/// 스캐폴딩용 임시 화면 — 화면 이름만 표시.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(name)),
    );
  }
}
