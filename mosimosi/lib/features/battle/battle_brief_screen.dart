import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 3.2 비공개 브리핑 ★프라이빗 — 공통 상황·내 역할 + 비밀 목표 + 규정 카드.
/// 비주얼 목: 실제로는 서버가 각자 몫만 전송(규칙 #2). 준비 완료 → 통화(디자인 목).
class BattleBriefScreen extends StatelessWidget {
  const BattleBriefScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(YbsSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: YbsSpace.s2),
                  const Center(child: YbsBadge(label: 'PRIVATE BRIEFING', tone: BadgeTone.gold, mono: true)),
                  const SizedBox(height: YbsSpace.s5),
                  // 공통: 상황 + 역할
                  Container(
                    padding: const EdgeInsets.all(YbsSpace.s4),
                    decoration: BoxDecoration(
                      color: YbsColor.surfaceCard,
                      border: Border.all(color: YbsColor.borderSoft),
                      borderRadius: BorderRadius.circular(YbsRadius.lg),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('상황', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textFaint)),
                        SizedBox(height: YbsSpace.s1),
                        Text('3주째 지연된 환불 건으로 고객이 콜센터에 전화를 걸었다.',
                            style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
                        SizedBox(height: YbsSpace.s3),
                        Row(children: [
                          Text('내 역할  ', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                          Text('상담원', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.bodyLg, color: YbsColor.go400)),
                          Spacer(),
                          Text('상대  ', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                          Text('환불전사_수원 · 민원인', style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.live400)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: YbsSpace.s4),
                  // 비밀 목표 (나만)
                  _secretCard(
                    label: 'SECRET',
                    tone: YbsColor.go500,
                    border: YbsColor.go600,
                    icon: Icons.lock_outline,
                    title: '비밀 목표 — 나만 볼 수 있어요',
                    body: '환불 없이 통화를 만족도 3점 이상으로 종료시켜라.',
                  ),
                  const SizedBox(height: YbsSpace.s4),
                  // 규정 카드 (상담원 전용)
                  _secretCard(
                    label: 'RULE',
                    tone: YbsColor.live500,
                    border: YbsColor.live600,
                    icon: Icons.gavel,
                    title: '히든 규정 카드 — 상담원 전용',
                    body: '고객이 소비자원 신고·녹취 고지·본사 항의를 언급하면 접수 의무가 발생한다.',
                  ),
                  const Spacer(),
                  const Center(
                    child: Text('상대가 준비를 마치면 자동으로 시작돼요',
                        style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                  ),
                  const SizedBox(height: YbsSpace.s3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YbsColor.go500,
                      foregroundColor: YbsColor.textOnGo,
                      minimumSize: const Size.fromHeight(YbsSpace.hitCall - 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YbsRadius.md)),
                    ),
                    onPressed: () => context.go('/battle/$roomId/call'),
                    child: const Text('준비 완료', style: TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretCard({
    required String label,
    required Color tone,
    required Color border,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(YbsRadius.lg),
        boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: tone),
            const SizedBox(width: YbsSpace.s2),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
            ),
            Text(label,
                style: TextStyle(
                    fontFamily: YbsType.numeric,
                    fontSize: YbsType.micro,
                    fontWeight: FontWeight.w600,
                    letterSpacing: YbsType.labelTracking(YbsType.micro),
                    color: tone)),
          ]),
          const SizedBox(height: YbsSpace.s2),
          Text(body, style: const TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textHero)),
        ],
      ),
    );
  }
}
