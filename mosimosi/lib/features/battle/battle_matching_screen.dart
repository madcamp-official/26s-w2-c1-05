import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 3.1 매칭 대기 — 검색중(경과) / 매칭 성사 / 30초 AI 폴백 제안.
/// 비주얼 목: 실제 매칭 큐(WebSocket)는 P1. 데모용으로 8초 후 성사,
/// 화면 탭으로도 상태 순환 가능.
class BattleMatchingScreen extends StatefulWidget {
  const BattleMatchingScreen({super.key});

  @override
  State<BattleMatchingScreen> createState() => _BattleMatchingScreenState();
}

enum _State { searching, matched, fallback }

class _BattleMatchingScreenState extends State<BattleMatchingScreen> {
  _State _state = _State.searching;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_state == _State.searching && _elapsed == 8) _state = _State.matched; // 목 성사
        if (_state == _State.searching && _elapsed >= 30) _state = _State.fallback;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cycle() {
    setState(() {
      _state = switch (_state) {
        _State.searching => _State.matched,
        _State.matched => _State.fallback,
        _State.fallback => _State.searching,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('전화 배틀', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.bodyLg)),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _cycle, // 목: 탭으로 상태 순환
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(YbsSpace.s6),
                child: switch (_state) {
                  _State.searching => _searching(),
                  _State.matched => _matched(context),
                  _State.fallback => _fallback(context),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searching() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: YbsColor.go500.withValues(alpha: 0.08),
            border: Border.all(color: YbsColor.go600, width: 2),
            boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 40)],
          ),
          child: const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(color: YbsColor.go400, strokeWidth: 3),
            ),
          ),
        ),
        const SizedBox(height: YbsSpace.s6),
        const Text('상대를 찾는 중…',
            style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.textHero)),
        const SizedBox(height: YbsSpace.s2),
        Text('경과 $_elapsed초 · 크로스 플랫폼 매칭',
            style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.sub, color: YbsColor.textFaint)),
        const SizedBox(height: YbsSpace.s10),
        OutlinedButton(
          onPressed: () => context.go('/home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: YbsColor.textSub,
            side: const BorderSide(color: YbsColor.borderStrong),
          ),
          child: const Text('취소'),
        ),
      ],
    );
  }

  Widget _matched(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: YbsBadge(label: 'MATCHED', tone: BadgeTone.go, pulse: true)),
        const SizedBox(height: YbsSpace.s5),
        Container(
          padding: const EdgeInsets.all(YbsSpace.s5),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.go600),
            borderRadius: BorderRadius.circular(YbsRadius.lg),
            boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 24)],
          ),
          child: Column(
            children: [
              const Text('환불전사_수원',
                  style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.textHero)),
              const SizedBox(height: YbsSpace.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.desktop_windows_outlined, size: 14, color: YbsColor.sky400),
                  SizedBox(width: 4),
                  Text('데스크톱에서 접속 · ELO 1698',
                      style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                ],
              ),
              const SizedBox(height: YbsSpace.s5),
              const Divider(height: 1, color: YbsColor.borderSoft),
              const SizedBox(height: YbsSpace.s4),
              const Text('내 역할', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
              const SizedBox(height: YbsSpace.s1),
              const Text('상담원',
                  style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, color: YbsColor.go400)),
            ],
          ),
        ),
        const SizedBox(height: YbsSpace.s6),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: YbsColor.go500,
            foregroundColor: YbsColor.textOnGo,
            minimumSize: const Size.fromHeight(YbsSpace.hitCall - 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YbsRadius.md)),
          ),
          onPressed: () => context.go('/battle/demo/brief'),
          child: const Text('브리핑 받기', style: TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.smart_toy_outlined, size: 56, color: YbsColor.gold400),
        const SizedBox(height: YbsSpace.s4),
        const Text('상대가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.textHero)),
        const SizedBox(height: YbsSpace.s2),
        const Text('AI 상담원과 배틀할까요?\n실제 유저처럼 봐주지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s6),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: YbsColor.gold400,
            foregroundColor: YbsColor.textOnGold,
            minimumSize: const Size.fromHeight(YbsSpace.hitCall - 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YbsRadius.md)),
          ),
          onPressed: () => context.go('/battle/demo/brief'),
          child: const Text('AI와 배틀', style: TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: YbsSpace.s3),
        OutlinedButton(
          onPressed: () => setState(() {
            _state = _State.searching;
            _elapsed = 0;
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: YbsColor.textSub,
            side: const BorderSide(color: YbsColor.borderStrong),
          ),
          child: const Text('계속 기다리기'),
        ),
      ],
    );
  }
}
