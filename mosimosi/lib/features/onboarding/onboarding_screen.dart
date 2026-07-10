import 'package:flutter/material.dart';

import '../../ui/placeholder_screen.dart';

/// 0. 온보딩 (소개 → 마이크 권한 → 닉네임)
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(name: 'Onboarding');
}
