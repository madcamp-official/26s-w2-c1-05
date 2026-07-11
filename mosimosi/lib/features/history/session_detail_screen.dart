import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 4.2.1 판 상세 — 트랜스크립트 리플레이 + 당시 리포트. 목 데이터
/// (Whisper 정제 트랜스크립트·DB는 P1.5/P2).
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  static const _lines = [
    ('boss', '환불 상담원', '네 고객센터입니다. 용건 말씀하세요.', '00:02'),
    ('user', '나', '지난주 주문한 이어폰이 불량이라 환불 요청드립니다.', '00:07'),
    ('boss', '환불 상담원', '고객님, 환불은 안 됩니다. 규정이에요.', '00:13'),
    ('user', '나', '그 규정이 몇 조 몇 항인지 확인해 주시겠어요?', '00:19'),
    ('boss', '환불 상담원', '…규정 7조 2항, 단순 변심 환불 불가 조항입니다.', '00:26'),
    ('user', '나', '변심이 아니라 하자잖아요. 환불 처리해 주세요.', '00:33'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('판 상세', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.bodyLg)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(YbsSpace.s5),
          children: [
            // 요약 헤더
            Container(
              padding: const EdgeInsets.all(YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.gold500),
                borderRadius: BorderRadius.circular(YbsRadius.lg),
              ),
              child: const Row(
                children: [
                  Text('WIN', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.gold400)),
                  SizedBox(width: YbsSpace.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('환불 불가 3연벙 상담원', style: TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                        Text('보스전 · 오늘 21:04 · 02:41', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                      ],
                    ),
                  ),
                  Text('82점', style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.title, fontWeight: FontWeight.w600, color: YbsColor.textHero)),
                ],
              ),
            ),
            const SizedBox(height: YbsSpace.s6),
            const Text('트랜스크립트 리플레이',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s3),
            for (final l in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: YbsSpace.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(l.$4,
                            style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, color: YbsColor.textFaint)),
                      ),
                    ),
                    Expanded(
                      child: LiveCaption(
                        speaker: l.$1 == 'boss' ? CaptionSpeaker.boss : CaptionSpeaker.player,
                        name: l.$2,
                        text: l.$3,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: YbsSpace.s4),
            const Text('당시 리포트',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s3),
            Container(
              padding: const EdgeInsets.all(YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.gold400.withValues(alpha: 0.10),
                border: Border.all(color: YbsColor.gold500),
                borderRadius: BorderRadius.circular(YbsRadius.md),
              ),
              child: const Text('오늘의 한마디 — 규정 조항을 콕 집어 물은 순간, 승부가 갈렸어요.',
                  style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.gold300)),
            ),
            const SizedBox(height: YbsSpace.s3),
            Container(
              padding: const EdgeInsets.all(YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.md),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('“어…” 시작이 3회 있었어요',
                      style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                  SizedBox(height: YbsSpace.s1),
                  Text('→ 첫 마디는 용건부터: "환불 요청드립니다."',
                      style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.go300)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
