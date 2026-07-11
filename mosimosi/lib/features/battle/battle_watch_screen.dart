import 'package:flutter/material.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 5. 관전 모드 — 양측 통화 뷰 + 중앙 모멘텀 게이지 + 실황 캐스터 자막.
/// 데스크톱 우선(가로 2열), 모바일은 세로 스택. 비밀 정보 미포함 (서버가
/// 관전 스트림에서 원천 제외 — 규칙 #2). 비주얼 목: 실시간 스트림은 P1.
class BattleWatchScreen extends StatelessWidget {
  const BattleWatchScreen({super.key, required this.roomId});

  final String roomId;

  static const _aLines = [
    ('민준 · 상담원', '많이 답답하셨겠어요. 어떤 부분이 제일 불편하셨는지 여쭤봐도 될까요?', false),
    ('민준 · 상담원', '우선 접수번호 드리고 담당 부서에서 바로 연락드리도록 할게요.', true),
  ];
  static const _bLines = [
    ('환불전사_수원 · 민원인', '3주째 환불 처리가 안 되고 있잖아요. 오늘은 답을 듣고 끊을 거예요.', false),
    ('환불전사_수원 · 민원인', '말 돌리지 마세요. 소비자원에 신고하기 전에 환불해 주세요.', true),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MomentumGauge(playerFraction: 0.46, leftLabel: '민준 · 상담원', rightLabel: '환불전사_수원 · 민원인'),
            _casterBar(),
            Expanded(
              child: desktop
                  ? Row(children: [
                      Expanded(child: _sideView('A측 — 상담원', YbsColor.go400, _aLines)),
                      const VerticalDivider(width: 1, color: YbsColor.borderSoft),
                      Expanded(child: _sideView('B측 — 민원인', YbsColor.live400, _bLines)),
                    ])
                  : ListView(children: [
                      _sideView('A측 — 상담원', YbsColor.go400, _aLines, shrink: true),
                      const Divider(height: 1, color: YbsColor.borderSoft),
                      _sideView('B측 — 민원인', YbsColor.live400, _bLines, shrink: true),
                    ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: YbsSpace.s4),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: YbsColor.live500, shape: BoxShape.circle)),
                  const SizedBox(width: YbsSpace.s2),
                  Text('SPECTATOR · ROOM $roomId',
                      style: TextStyle(
                          fontFamily: YbsType.numeric,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: YbsType.labelTracking(11),
                          color: YbsColor.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _casterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5, vertical: YbsSpace.s3),
      decoration: BoxDecoration(
        color: YbsColor.gold400.withValues(alpha: 0.08),
        border: const Border(bottom: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Row(
        children: [
          const YbsBadge(label: 'CASTER', tone: BadgeTone.gold, pulse: true, mono: true),
          const SizedBox(width: YbsSpace.s3),
          const Expanded(
            child: Text('소비자원이 나왔습니다! 규정 카드 발동 조건 — 상담원이 접수를 안내할까요?!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: YbsType.sub, fontStyle: FontStyle.italic, height: 1.4, color: YbsColor.gold300)),
          ),
        ],
      ),
    );
  }

  Widget _sideView(String title, Color tone, List<(String, String, bool)> lines, {bool shrink = false}) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: tone)),
        const SizedBox(height: YbsSpace.s3),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: YbsSpace.s3),
            child: LiveCaption(
              speaker: tone == YbsColor.go400 ? CaptionSpeaker.player : CaptionSpeaker.boss,
              name: l.$1,
              text: l.$2,
              active: l.$3,
              dim: !l.$3,
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(YbsSpace.s5),
      child: shrink ? list : SingleChildScrollView(reverse: true, child: list),
    );
  }
}
