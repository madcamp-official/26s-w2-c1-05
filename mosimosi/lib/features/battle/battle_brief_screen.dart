import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';
import '../../ui/components.dart';

/// 3.2 배틀 브리핑 (비공개) — 디자인 H 섹션 이식.
/// 공통 상황 + 비밀 구분선 + 비밀 목표(SECRET) + 규칙 카드(RULE).
/// 비주얼 목: 실제로는 서버가 각자 몫만 전송(규칙 #2).
class BattleBriefScreen extends StatelessWidget {
  const BattleBriefScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: YbsSpace.s5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('배틀 브리핑',
                          style: TextStyle(fontFamily: YbsType.display, fontSize: 22, height: 1.2, color: YbsColor.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: YbsColor.amber400.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(YbsRadius.full),
                        ),
                        child: const Text('시작까지 00:12',
                            style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.amber400)),
                      ),
                    ],
                  ),
                  const SizedBox(height: YbsSpace.s4),
                  // 공통 상황
                  Container(
                    padding: const EdgeInsets.all(YbsSpace.s4),
                    decoration: BoxDecoration(
                      color: YbsColor.surfaceCard,
                      border: Border.all(color: YbsColor.borderSoft),
                      borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('공통 상황 · 양쪽 모두 확인',
                            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.textFaint)),
                        const SizedBox(height: YbsSpace.s2 + 2),
                        const Text('온라인 쇼핑몰 「급배송」 환불 분쟁. 민원인이 3주째 환불을 요구하고 있습니다.',
                            style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
                        const SizedBox(height: YbsSpace.s2 + 2),
                        Row(children: [
                          _rolePill('나 · 상담원', YbsColor.go300, YbsColor.go600, YbsColor.go500.withValues(alpha: 0.10)),
                          const SizedBox(width: YbsSpace.s2 + 2),
                          _rolePill('환불전사_수원 · 민원인', YbsColor.live400, YbsColor.live600, YbsColor.live500.withValues(alpha: 0.10)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // 비밀 구분선
                  Row(children: [
                    const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s2 + 2),
                      child: Row(children: [
                        const Icon(Icons.lock_outline, size: 14, color: YbsColor.gold300),
                        const SizedBox(width: 6),
                        Text('여기부터는 비밀 — 상대에게 보이지 않아요',
                            style: TextStyle(
                                fontSize: YbsType.micro,
                                fontWeight: FontWeight.w700,
                                letterSpacing: YbsType.labelTracking(YbsType.micro),
                                color: YbsColor.gold300)),
                      ]),
                    ),
                    const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
                  ]),
                  const SizedBox(height: YbsSpace.s4 - 2),
                  _secretCard(
                    header: '비밀 목표',
                    tag: 'SECRET',
                    accent: YbsColor.go400,
                    border: YbsColor.go600,
                    bg: YbsColor.go500.withValues(alpha: 0.06),
                    glow: YbsColor.go500.withValues(alpha: 0.10),
                    body: const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '환불 없이 '),
                        TextSpan(text: '만족도 3점 이상', style: TextStyle(color: YbsColor.go300)),
                        TextSpan(text: '으로 통화를 종료하세요.'),
                      ]),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero),
                    ),
                    note: '달성 시 기세 보너스 +20',
                  ),
                  const SizedBox(height: YbsSpace.s4 - 2),
                  _secretCard(
                    header: '규칙 카드 · 상담원 전용',
                    tag: 'RULE',
                    accent: YbsColor.live400,
                    border: YbsColor.borderIncall,
                    bg: YbsColor.live500.withValues(alpha: 0.05),
                    glow: null,
                    body: const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '고객이 '),
                        TextSpan(text: '소비자원 신고', style: TextStyle(color: YbsColor.live400)),
                        TextSpan(text: '를 언급하면 접수 의무가 발생합니다.'),
                      ]),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero),
                    ),
                    note: '접수를 미루면 기세가 계속 깎여요',
                  ),
                  const Spacer(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: YbsButton(
                        label: '준비 완료',
                        size: YbsButtonSize.lg,
                        fullWidth: true,
                        onTap: () => context.go('/battle/$roomId/call'),
                      ),
                    ),
                  ),
                  const SizedBox(height: YbsSpace.s2 + 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: YbsColor.amber400, shape: BoxShape.circle)),
                      const SizedBox(width: YbsSpace.s2),
                      const Text('상대 준비 중…', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolePill(String label, Color fg, Color border, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(YbsRadius.full)),
        child: Text(label, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _secretCard({
    required String header,
    required String tag,
    required Color accent,
    required Color border,
    required Color bg,
    required Color? glow,
    required Widget body,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        boxShadow: glow == null ? null : [BoxShadow(color: glow, blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(header,
                  style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: accent)),
              Text(tag,
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(10), color: accent)),
            ],
          ),
          const SizedBox(height: YbsSpace.s2),
          body,
          const SizedBox(height: YbsSpace.s2),
          Text(note, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
        ],
      ),
    );
  }
}
