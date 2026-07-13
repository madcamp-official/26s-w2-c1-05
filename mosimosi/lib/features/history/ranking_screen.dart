import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 4.3 랭킹 (배틀 ELO) — 목 데이터. ELO·서버 연동은 P2.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  static const _rows = [
    (1, '전화의신_판교', 1842, false),
    (2, '콜포비아극복러', 1731, false),
    (3, '환불전사_수원', 1698, false),
    (4, '민원마스터', 1655, false),
    (5, '나', 1602, true),
    (6, '수줍은상담원', 1544, false),
    (7, '따발총킬러', 1490, false),
    (8, '전화못하는사람', 1411, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const YbsHeader(title: '배틀 랭킹'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(YbsSpace.s5),
                children: [
                  for (final r in _rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: YbsSpace.s3),
                      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3),
                      decoration: BoxDecoration(
                        color: YbsColor.surfaceCard,
                        border: Border.all(color: r.$4 ? YbsColor.gold400 : YbsColor.borderSoft),
                        borderRadius: BorderRadius.circular(YbsRadius.md),
                        boxShadow: r.$4 ? [BoxShadow(color: YbsColor.goldGlow, blurRadius: 16)] : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${r.$1}',
                              style: TextStyle(
                                fontFamily: YbsType.numeric,
                                fontSize: YbsType.bodyLg,
                                fontWeight: FontWeight.w600,
                                color: switch (r.$1) {
                                  1 => YbsColor.gold400,
                                  2 => YbsColor.ink200,
                                  3 => const Color(0xFFCD8C52),
                                  _ => YbsColor.textFaint,
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(r.$2,
                                style: TextStyle(
                                    fontSize: YbsType.bodyMd,
                                    fontWeight: r.$4 ? FontWeight.w800 : FontWeight.w500,
                                    color: r.$4 ? YbsColor.gold300 : YbsColor.textBody)),
                          ),
                          Text('${r.$3}',
                              style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyMd, fontWeight: FontWeight.w600, color: YbsColor.textSub)),
                          const SizedBox(width: 4),
                          const Text('ELO', style: TextStyle(fontSize: 10, color: YbsColor.textFaint)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
