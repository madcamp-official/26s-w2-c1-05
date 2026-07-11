import 'package:flutter/material.dart';

import 'theme.dart';

/// 여보세요 통화 화면 공유 위젯 (design-system components/core + components/call).
/// 프로토타입 JSX(Badge, CallTimer, LiveCaption, IconButton, HudPanel)의 Flutter 이식.
/// 애니메이션(펄스/셰이크/링)은 이번 핸드오프 스코프 밖 → 정지 상태 시각만 반영.

// ─────────────────────────────────────────────────────────── Badge
enum BadgeTone { live, go, gold, caution, neutral }

class YbsBadge extends StatelessWidget {
  const YbsBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.pulse = false, this.mono = false});

  final String label;
  final BadgeTone tone;
  final bool pulse;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      BadgeTone.live => (YbsColor.live500.withValues(alpha:0.14), YbsColor.live400, YbsColor.live600),
      BadgeTone.go => (YbsColor.go500.withValues(alpha:0.12), YbsColor.go400, YbsColor.go600),
      BadgeTone.gold => (YbsColor.gold400.withValues(alpha:0.12), YbsColor.gold300, YbsColor.gold500),
      BadgeTone.caution => (YbsColor.amber400.withValues(alpha:0.12), YbsColor.amber400, YbsColor.amber400.withValues(alpha:0.5)),
      BadgeTone.neutral => (YbsColor.ink700, YbsColor.textSub, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s3, vertical: YbsSpace.s1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(YbsRadius.full),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: YbsSpace.s2 - 1),
          ],
          Text(label,
              style: TextStyle(
                fontFamily: mono ? YbsType.numeric : YbsType.body,
                fontSize: YbsType.micro,
                fontWeight: FontWeight.w700,
                letterSpacing: YbsType.labelTracking(YbsType.micro),
                color: fg,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── CallTimer
enum TimerTone { normal, warning, critical }

class CallTimer extends StatelessWidget {
  const CallTimer({super.key, required this.seconds, this.tone = TimerTone.normal, this.label, this.size = YbsType.timer});

  final int seconds;
  final TimerTone tone;
  final String? label;
  final double size;

  String get _fmt {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TimerTone.normal => YbsColor.textHero,
      TimerTone.warning => YbsColor.amber400,
      TimerTone.critical => YbsColor.live400,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_fmt,
            style: TextStyle(
              fontFamily: YbsType.numeric,
              fontWeight: FontWeight.w600,
              fontSize: size,
              height: 1.1,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        if (label != null)
          Text(label!,
              style: TextStyle(
                fontFamily: YbsType.body,
                fontSize: YbsType.micro,
                fontWeight: FontWeight.w700,
                letterSpacing: YbsType.labelTracking(YbsType.micro),
                color: tone == TimerTone.normal ? YbsColor.textFaint : color,
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── LiveCaption
enum CaptionSpeaker { boss, player }

class LiveCaption extends StatelessWidget {
  const LiveCaption({
    super.key,
    required this.speaker,
    required this.name,
    required this.text,
    this.active = false,
    this.dim = false,
  });

  final CaptionSpeaker speaker;
  final String name;
  final String text;
  final bool active;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final isBoss = speaker == CaptionSpeaker.boss;
    final nameColor = isBoss ? YbsColor.live400 : YbsColor.go400;
    final bubble = isBoss ? YbsColor.live500.withValues(alpha:0.10) : YbsColor.go500.withValues(alpha:0.08);
    final borderColor = active
        ? (isBoss ? YbsColor.live600 : YbsColor.go600)
        : YbsColor.borderSoft;
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: isBoss ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(name, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: nameColor)),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4 - 2, vertical: YbsSpace.s3 - 2),
            decoration: BoxDecoration(
              color: bubble,
              borderRadius: isBoss
                  ? const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(YbsRadius.md), bottomLeft: Radius.circular(YbsRadius.md), bottomRight: Radius.circular(YbsRadius.md))
                  : const BorderRadius.only(topLeft: Radius.circular(YbsRadius.md), topRight: Radius.circular(4), bottomLeft: Radius.circular(YbsRadius.md), bottomRight: Radius.circular(YbsRadius.md)),
              border: Border.all(color: borderColor),
            ),
            child: Text(text,
                style: const TextStyle(
                  fontFamily: YbsType.body,
                  fontSize: YbsType.captionLive,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: YbsColor.textHero,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── HudPanel (desktop only)
enum HudTone { neutral, live, go, gold }

class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.title,
    this.label,
    this.tone = HudTone.neutral,
    this.live = false,
    required this.child,
    this.expand = false,
  });

  final String title;
  final String? label;
  final HudTone tone;
  final bool live;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (border, accent, glow) = switch (tone) {
      HudTone.neutral => (YbsColor.borderSoft, YbsColor.textSub, null),
      HudTone.live => (const Color(0xFF3A1B22), YbsColor.live500, null),
      HudTone.go => (YbsColor.go600, YbsColor.go500, YbsColor.goGlow),
      HudTone.gold => (YbsColor.gold500, YbsColor.gold400, YbsColor.goldGlow),
    };
    return Container(
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(YbsRadius.md),
        boxShadow: [
          ...YbsShadow.card,
          if (glow != null) BoxShadow(color: glow, blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.all(YbsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontFamily: YbsType.body, fontWeight: FontWeight.w700, fontSize: YbsType.sub, height: YbsType.leadingSnug, color: YbsColor.textBody)),
              ),
              if (label != null) ...[
                if (live) ...[
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                Text(label!,
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(YbsType.micro), color: accent)),
              ],
            ],
          ),
          const SizedBox(height: YbsSpace.s3),
          if (expand) Expanded(child: SingleChildScrollView(child: child)) else child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── CallIconButton
enum CallButtonKind { neutral, endCall }

class CallIconButton extends StatelessWidget {
  const CallIconButton({super.key, required this.icon, this.label, this.kind = CallButtonKind.neutral, this.onTap, this.size = 56});

  final IconData icon;
  final String? label;
  final CallButtonKind kind;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (kind) {
      CallButtonKind.neutral => (YbsColor.ink700, YbsColor.borderStrong, YbsColor.ink200),
      CallButtonKind.endCall => (YbsColor.live500.withValues(alpha:0.08), const Color(0xFF3A1B22), YbsColor.live400),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border)),
            child: Icon(icon, size: size * 0.4, color: fg),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: YbsSpace.s2),
          Text(label!, style: const TextStyle(fontFamily: YbsType.body, fontSize: YbsType.micro, color: YbsColor.textSub)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── PhoneFrame (desktop stage)
/// 데스크톱에서 모바일 통화 위젯을 감싸는 폰 목업 베젤. 폭 고정(--stage-phone-w).
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: YbsLayout.stagePhoneW,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: YbsColor.bgApp,
          borderRadius: BorderRadius.circular(YbsLayout.stagePhoneRadius),
          border: Border.all(color: YbsColor.borderStrong),
          boxShadow: [
            ...YbsShadow.pop,
            BoxShadow(color: YbsColor.live500.withValues(alpha:0.12), blurRadius: 40),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(YbsLayout.stagePhoneRadius),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── MomentumGauge (desktop top strip)
class MomentumGauge extends StatelessWidget {
  const MomentumGauge({super.key, required this.playerFraction, required this.rightLabel, this.leftLabel = '나'});

  final double playerFraction; // 0..1
  final String rightLabel;
  final String leftLabel;

  @override
  Widget build(BuildContext context) {
    final pct = (playerFraction * 100).round();
    return Container(
      height: YbsLayout.stageTopH,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s8),
      decoration: const BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border(bottom: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Row(
        children: [
          const YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
          const SizedBox(width: YbsSpace.s3),
          Text('MOMENTUM',
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(YbsType.micro), color: YbsColor.textFaint)),
          const SizedBox(width: YbsSpace.s6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(leftLabel, style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.go400)),
                    Text(rightLabel, style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.live400)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(YbsRadius.full),
                  child: Container(
                    height: 10,
                    color: YbsColor.live600,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: playerFraction.clamp(0, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: YbsColor.go500,
                          boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: YbsSpace.s6),
          Text('$pct%', style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 20, fontWeight: FontWeight.w600, color: YbsColor.go400)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── CallDesktopStage
/// expanded 레이아웃: 상단 모멘텀 게이지 + [좌 HUD | 중앙 폰 | 우 HUD] 3열.
/// 중앙 폰은 모바일 통화 위젯을 그대로 재사용(PhoneFrame). 좁은 창은 가로 스크롤로 폴백.
class CallDesktopStage extends StatelessWidget {
  const CallDesktopStage({
    super.key,
    required this.gauge,
    required this.leftPanels,
    required this.phone,
    required this.rightPanels,
  });

  final Widget gauge;
  final List<Widget> leftPanels;
  final Widget phone;
  final List<Widget> rightPanels;

  Widget _column(List<Widget> panels) {
    // 마지막 패널(이벤트 타임라인 / 캡션 로그)이 남은 높이를 채우도록 flex.
    // → 내부 Expanded(스크롤)가 유한 높이를 받아 unbounded-height 오류를 방지.
    final children = <Widget>[];
    for (var i = 0; i < panels.length; i++) {
      if (i > 0) children.add(const SizedBox(height: YbsLayout.stageGap));
      final isLast = i == panels.length - 1;
      children.add(isLast ? Expanded(child: panels[i]) : panels[i]);
    }
    return SizedBox(
      width: YbsLayout.stageHudW,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        gauge,
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: SizedBox(
                  height: c.maxHeight,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: YbsLayout.screenPadDesktop, vertical: YbsLayout.stageGap),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _column(leftPanels),
                          const SizedBox(width: YbsLayout.stageGap),
                          PhoneFrame(child: phone),
                          const SizedBox(width: YbsLayout.stageGap),
                          _column(rightPanels),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
