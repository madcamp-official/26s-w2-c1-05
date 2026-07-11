import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 3.1 배틀 매칭 — 디자인 G 섹션 이식.
/// 탐색 중(경과 타이머) → 매칭 완료(VS·역할 배정) → 30초 폴백(AI 배틀 시트).
/// 비주얼 목: 실제 매칭 큐(WebSocket)는 P1. 데모용 8초 후 성사.
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

  String get _mmss =>
      '${(_elapsed ~/ 60).toString().padLeft(2, '0')}:${(_elapsed % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_state) {
          _State.searching => _searching(),
          _State.matched => _matched(),
          _State.fallback => _fallback(),
        },
      ),
    );
  }

  // ---- 탐색 중 ----
  Widget _searching({bool dimmed = false}) {
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.72,
                colors: [YbsColor.go500.withValues(alpha: 0.16), Colors.transparent],
              ),
              border: Border.all(color: YbsColor.go600, width: 2),
              boxShadow: dimmed ? null : [BoxShadow(color: YbsColor.goGlow, blurRadius: 32)],
            ),
            child: const Icon(Icons.call, size: 42, color: YbsColor.go400),
          ),
          const SizedBox(height: YbsSpace.s5),
          const Text('상대를 찾는 중…',
              style: TextStyle(fontFamily: YbsType.display, fontSize: 28, height: 1.2, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          Text(_mmss,
              style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 32, fontWeight: FontWeight.w600, height: 1.1, color: YbsColor.go400)),
          if (!dimmed) ...[
            const SizedBox(height: YbsSpace.s2),
            const Text('비슷한 레벨의 상대를 찾고 있어요.\n평균 대기 20초',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textSub)),
            const SizedBox(height: YbsSpace.s5),
            YbsButton(label: '취소', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
          ],
        ],
      ),
    );
    return dimmed
        ? Opacity(opacity: 0.28, child: IgnorePointer(child: body))
        : body;
  }

  // ---- 매칭 완료 ----
  Widget _matched() {
    Widget player({
      required String syllable,
      required String name,
      required String role,
      required bool isMe,
    }) {
      final accent = isMe ? YbsColor.go400 : YbsColor.live400;
      final border = isMe ? YbsColor.go600 : YbsColor.live600;
      final glow = isMe ? YbsColor.goGlow : YbsColor.liveGlow;
      return SizedBox(
        width: 120,
        child: Column(children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              gradient: RadialGradient(
                center: const Alignment(0, -0.24),
                radius: 0.72,
                colors: [accent.withValues(alpha: 0.25), Colors.transparent],
              ),
              border: Border.all(color: border, width: 2),
              boxShadow: [BoxShadow(color: glow, blurRadius: 26)],
            ),
            alignment: Alignment.center,
            child: Text(syllable,
                style: TextStyle(fontFamily: YbsType.display, fontSize: 34, height: 1, color: accent)),
          ),
          const SizedBox(height: YbsSpace.s2 + 2),
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2 + 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: Text(role, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: accent)),
          ),
        ]),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('상대를 찾았어요!',
                style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1.2, color: YbsColor.textHero)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                player(syllable: '민', name: '민준', role: '상담원', isMe: true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: YbsSpace.s4 + 2),
                  child: Text('VS',
                      style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1, color: YbsColor.live500)),
                ),
                player(syllable: '환', name: '환불전사_수원', role: '민원인', isMe: false),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: 7),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.desktop_windows_outlined, size: 14, color: YbsColor.sky400),
                  SizedBox(width: YbsSpace.s2),
                  Text('상대는 Windows에서 접속 중', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
                ],
              ),
            ),
            const SizedBox(height: YbsSpace.s2),
            const Text('시즌 승률이 비슷한 상대예요 (12승 vs 11승)',
                style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(children: [
                YbsButton(
                  label: '준비 완료',
                  size: YbsButtonSize.lg,
                  fullWidth: true,
                  onTap: () => context.go('/battle/demo/brief'),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                const Text('5초 후 자동 시작',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, color: YbsColor.textFaint)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 30초 폴백 시트 ----
  Widget _fallback() {
    return Stack(
      children: [
        _searching(dimmed: true),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s6, YbsSpace.s5, 30),
            decoration: const BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border(top: BorderSide(color: YbsColor.borderStrong)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(YbsRadius.xl)),
              boxShadow: YbsShadow.pop,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: YbsColor.ink500, borderRadius: BorderRadius.circular(YbsRadius.full)),
                  ),
                ),
                const SizedBox(height: YbsSpace.s4 - 2),
                const Text('상대가 없어요',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.2, color: YbsColor.textHero)),
                const SizedBox(height: YbsSpace.s3),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '30초 동안 상대를 찾지 못했어요.\n'),
                    TextSpan(text: 'AI 상담원과 배틀', style: TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textBody)),
                    TextSpan(text: '할까요? 기세 시스템은 똑같이 작동해요.'),
                  ]),
                  style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textSub),
                ),
                const SizedBox(height: YbsSpace.s4 + 2),
                YbsButton(
                  label: 'AI와 배틀하기',
                  size: YbsButtonSize.lg,
                  fullWidth: true,
                  onTap: () => context.go('/battle/demo/brief'),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                YbsButton(
                  label: '계속 기다리기',
                  variant: YbsButtonVariant.secondary,
                  fullWidth: true,
                  onTap: () => setState(() {
                    _state = _State.searching;
                    _elapsed = 0;
                  }),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                YbsButton(
                  label: '나가기',
                  variant: YbsButtonVariant.ghost,
                  size: YbsButtonSize.sm,
                  fullWidth: true,
                  onTap: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
