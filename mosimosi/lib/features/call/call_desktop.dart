import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../battle/battle_room.dart';

/// 배틀 통화 데스크톱 스테이지 (4b 데스크톱 — 좌측 5필드 HUD 상시 노출).
/// 상단 기세 게이지 + 좌(목표·상황·물러설 수 없는 선·비밀) · 중앙 폰 · 우(코치·캡션 로그).
/// AI 대전은 CallDesktopStage를 직접 조립하므로, 이 헬퍼는 배틀 전용이다.
Widget buildCallDesktopStage({
  required Widget phone,
  required BattleMatch match,
  required double momentum,
  required String coachHint,
  required List<({bool mine, String text})> captions,
  required bool showOpponentCaptions,
}) {
  const panelText = TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody, color: YbsColor.textBody);

  return CallDesktopStage(
    gauge: MomentumGauge(playerFraction: momentum, rightLabel: match.opponentNickname),
    leftPanels: [
      HudPanel(
        title: '목표',
        label: 'GOAL',
        tone: HudTone.go,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.goal,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: YbsColor.textHero)),
            if (match.winNote.isNotEmpty) ...[
              const SizedBox(height: YbsSpace.s2),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '승패  ', style: TextStyle(fontWeight: FontWeight.w700, color: YbsColor.sky400)),
                  TextSpan(text: match.winNote, style: const TextStyle(color: YbsColor.textSub)),
                ]),
                style: const TextStyle(fontSize: YbsType.micro, height: 1.45),
              ),
            ],
          ],
        ),
      ),
      HudPanel(
        title: '당신의 상황',
        tone: HudTone.neutral,
        child: Text(match.personal, style: panelText),
      ),
      HudPanel(
        title: '물러설 수 없는 선',
        label: 'HARD LINE',
        tone: HudTone.live,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.hardLine,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.45, color: YbsColor.textHero)),
            for (final e in match.exceptions)
              Padding(
                padding: const EdgeInsets.only(top: YbsSpace.s2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.subdirectory_arrow_right, size: 13, color: YbsColor.amber400),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e, style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textSub))),
                  ],
                ),
              ),
          ],
        ),
      ),
      HudPanel(
        title: '들키면 안 되는 비밀',
        label: 'TOP SECRET',
        tone: HudTone.gold,
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.secret,
                style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.55, color: Color(0xFFF5E6C0))),
            const SizedBox(height: YbsSpace.s2),
            const Text('나만 볼 수 있어요 — 상대가 눈치채면 불리해져요',
                style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
          ],
        ),
      ),
    ],
    phone: phone,
    rightPanels: [
      HudPanel(
        title: '코치의 속삭임',
        label: 'LIVE',
        tone: HudTone.gold,
        live: true,
        child: Text(
          coachHint.isEmpty ? '통화가 이어지면 실시간 코치가 힌트를 줘요.' : coachHint,
          style: coachHint.isEmpty
              ? const TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody, color: YbsColor.textFaint)
              : panelText,
        ),
      ),
      HudPanel(
        title: '캡션 로그',
        label: 'REC',
        live: true,
        expand: true,
        child: captions.isEmpty
            ? const Text('아직 발화가 없어요.', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in captions)
                    if (c.mine || showOpponentCaptions)
                      _LogLine(
                        who: c.mine ? '나' : match.opponentNickname,
                        whoColor: c.mine ? YbsColor.go400 : YbsColor.live400,
                        text: c.text,
                        textColor: YbsColor.textBody,
                      ),
                ],
              ),
      ),
    ],
  );
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
