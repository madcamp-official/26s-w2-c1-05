import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 데스크톱 통화 스테이지 조립 — 프로토타입 InCallDesktopScreen.jsx 이식.
/// 상단 모멘텀 게이지 + 좌(비밀목표/규칙/타임라인) · 중앙 폰 · 우(코치/캡션로그).
/// 프로토타입은 통화 데스크톱 스테이지를 하나(InCallDesktopScreen)로 정의하므로
/// 보스전·배틀이 같은 스테이지를 공유하고, 중앙 폰 본문과 게이지 상대 라벨만 다르다.
Widget buildCallDesktopStage({
  required Widget phone,
  required String rightLabel,
  required double momentum,
  required String mission,
}) {
  const panelText = TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody, color: YbsColor.textBody);

  return CallDesktopStage(
    gauge: MomentumGauge(playerFraction: momentum, rightLabel: rightLabel),
    leftPanels: [
      HudPanel(
        title: '비밀 목표',
        label: 'SECRET',
        tone: HudTone.go,
        child: Text(mission, style: panelText),
      ),
      const HudPanel(
        title: '이번 판의 규칙',
        label: 'RULE',
        tone: HudTone.live,
        child: Text('"어…" "그…" 같은 군말 5회 초과 시 기세 −10.', style: panelText),
      ),
      HudPanel(
        title: '이벤트 타임라인',
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Event(t: '00:12', label: '보스가 규정을 언급', color: YbsColor.live400),
            _Event(t: '00:31', label: '핵심 질문 성공 +12', color: YbsColor.go400),
            _Event(t: '00:48', label: '침묵 3초 — 기세 하락', color: YbsColor.textFaint),
            _Event(t: '01:05', label: '조항 번호 요구 +18', color: YbsColor.go400),
          ],
        ),
      ),
    ],
    phone: phone,
    rightPanels: [
      const HudPanel(
        title: '코치의 속삭임',
        label: 'LIVE',
        tone: HudTone.gold,
        live: true,
        child: Text('지금이에요 — 조항 번호를 콕 집어 물어보세요. 침묵을 두려워하지 마세요.', style: panelText),
      ),
      HudPanel(
        title: '캡션 로그',
        label: 'REC',
        live: true,
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogLine(who: rightLabel, whoColor: YbsColor.live400, text: '네 고객센터입니다. 용건 말씀하세요.', textColor: YbsColor.textFaint),
            _LogLine(who: '나', whoColor: YbsColor.go400, text: '지난주 주문한 상품 환불 요청드립니다.', textColor: YbsColor.textFaint),
            _LogLine(who: rightLabel, whoColor: YbsColor.live400, text: '환불은 안 됩니다. 규정이에요.', textColor: YbsColor.textSub),
            const _LogLine(who: '나', whoColor: YbsColor.go400, text: '어떤 규정인지 조항을 확인해 주시겠어요?', textColor: YbsColor.textBody),
          ],
        ),
      ),
    ],
  );
}

class _Event extends StatelessWidget {
  const _Event({required this.t, required this.label, required this.color});
  final String t;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: YbsSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.textFaint)),
          const SizedBox(width: YbsSpace.s3),
          Expanded(child: Text(label, style: TextStyle(fontSize: YbsType.sub, color: color))),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.who, required this.whoColor, required this.text, required this.textColor});
  final String who;
  final Color whoColor;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: YbsSpace.s3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$who ', style: TextStyle(fontWeight: FontWeight.w700, color: whoColor)),
          TextSpan(text: '— $text', style: TextStyle(color: textColor)),
        ]),
        style: const TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody),
      ),
    );
  }
}
