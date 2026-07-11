import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 여보세요 공유 위젯 — 디자인 시스템 컴포넌트(JSX)의 Flutter 이식.
/// 통화(라이브 레지스터) 컴포넌트는 incall 토큰, 나머지는 게임 기본 토큰 사용.
/// 애니메이션(펄스/스탬프/링)은 스코프 밖 → 정지 상태 시각만 반영.

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
      BadgeTone.live => (YbsColor.live500.withValues(alpha: 0.14), YbsColor.live400, YbsColor.live600),
      BadgeTone.go => (YbsColor.go500.withValues(alpha: 0.12), YbsColor.go400, YbsColor.go600),
      BadgeTone.gold => (YbsColor.gold400.withValues(alpha: 0.12), YbsColor.gold300, YbsColor.gold500),
      BadgeTone.caution => (YbsColor.amber400.withValues(alpha: 0.12), YbsColor.amber400, YbsColor.amber400.withValues(alpha: 0.5)),
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

// ─────────────────────────────────────────────────────────── Button (core/Button.jsx)
enum YbsButtonVariant { primary, danger, gold, secondary, ghost }

enum YbsButtonSize { sm, md, lg }

class YbsButton extends StatelessWidget {
  const YbsButton({
    super.key,
    required this.label,
    this.variant = YbsButtonVariant.primary,
    this.size = YbsButtonSize.md,
    this.fullWidth = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final YbsButtonVariant variant;
  final YbsButtonSize size;
  final bool fullWidth;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      YbsButtonVariant.primary => (YbsColor.go500, YbsColor.textOnGo, Colors.transparent),
      YbsButtonVariant.danger => (YbsColor.live500, YbsColor.textOnLive, Colors.transparent),
      YbsButtonVariant.gold => (YbsColor.gold400, YbsColor.textOnGold, Colors.transparent),
      YbsButtonVariant.secondary => (YbsColor.surfaceCard, YbsColor.textBody, YbsColor.borderStrong),
      YbsButtonVariant.ghost => (Colors.transparent, YbsColor.textSub, Colors.transparent),
    };
    final (height, hPad, fontSize) = switch (size) {
      YbsButtonSize.sm => (40.0, 16.0, 14.0),
      YbsButtonSize.md => (48.0, 22.0, 16.0),
      YbsButtonSize.lg => (56.0, 28.0, 18.0),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 4, color: fg),
              const SizedBox(width: YbsSpace.s2),
            ],
            Text(label,
                style: TextStyle(fontFamily: YbsType.body, fontSize: fontSize, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── DifficultyMeter (boss/DifficultyMeter.jsx)
class DifficultyMeter extends StatelessWidget {
  const DifficultyMeter({super.key, required this.level, this.max = 5, this.size = 12});

  final int level;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = level >= 5
        ? YbsColor.gold400
        : level >= 4
            ? YbsColor.live500
            : YbsColor.amber400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: Icon(
              i < level ? Icons.star : Icons.star_border,
              size: size + 2,
              color: i < level ? color : YbsColor.ink500,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── BossCard (boss/BossCard.jsx)
enum BossTierUi { normal, rare, boss, legend }

class BossCardUi extends StatelessWidget {
  const BossCardUi({
    super.key,
    required this.number,
    required this.name,
    required this.title,
    required this.tier,
    required this.difficulty,
    this.locked = false,
    this.cleared = false,
    this.onTap,
  });

  final int number;
  final String name;
  final String title;
  final BossTierUi tier;
  final int difficulty;
  final bool locked;
  final bool cleared;
  final VoidCallback? onTap;

  (String, Color, Color) get _tier => switch (tier) {
        BossTierUi.normal => ('일반', YbsColor.ink300, YbsColor.ink300.withValues(alpha: 0.16)),
        BossTierUi.rare => ('희귀', YbsColor.sky400, YbsColor.sky400.withValues(alpha: 0.20)),
        BossTierUi.boss => ('보스', YbsColor.live500, YbsColor.live500.withValues(alpha: 0.22)),
        BossTierUi.legend => ('전설', YbsColor.gold400, YbsColor.gold400.withValues(alpha: 0.22)),
      };

  @override
  Widget build(BuildContext context) {
    final (tierLabel, tierColor, tierSpot) = _tier;
    final syllable = locked ? null : (name.isEmpty ? '?' : name.characters.first);
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.lg),
            boxShadow: tier == BossTierUi.legend && !locked
                ? [BoxShadow(color: YbsColor.goldGlow, blurRadius: 28), BoxShadow(color: YbsColor.gold500, blurRadius: 0, spreadRadius: 1)]
                : YbsShadow.card,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 초상 영역 (height = width * 0.72)
                  Container(
                    height: w * 0.72,
                    decoration: BoxDecoration(
                      color: YbsColor.surfaceInset,
                      gradient: locked
                          ? null
                          : RadialGradient(
                              center: const Alignment(0, -0.16),
                              radius: 0.7,
                              colors: [tierSpot, Colors.transparent],
                            ),
                    ),
                    alignment: Alignment.center,
                    child: locked
                        ? const Icon(Icons.lock, size: 30, color: YbsColor.ink500)
                        : Text(syllable!,
                            style: TextStyle(fontFamily: YbsType.display, fontSize: w * 0.34, height: 1, color: tierColor)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(YbsSpace.s3, YbsSpace.s2 + 2, YbsSpace.s3, YbsSpace.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(locked ? '???' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: YbsType.display,
                                fontSize: 17,
                                height: 1.2,
                                color: locked ? YbsColor.textFaint : YbsColor.textHero)),
                        const SizedBox(height: 3),
                        Text(locked ? '아직 만나지 못했어요' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: YbsColor.textSub)),
                        const SizedBox(height: YbsSpace.s2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DifficultyMeter(level: difficulty, size: 11),
                            Text(tierLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: YbsType.labelTracking(10),
                                    color: locked ? YbsColor.textFaint : tierColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 10,
                left: 12,
                child: Text('No.${number.toString().padLeft(3, '0')}',
                    style: TextStyle(
                        fontFamily: YbsType.numeric,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: locked ? YbsColor.textFaint : tierColor)),
              ),
              if (cleared && !locked)
                Positioned(
                  top: 8,
                  right: 10,
                  child: Transform.rotate(
                    angle: 6 * math.pi / 180,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: YbsColor.go600, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('격파',
                          style: TextStyle(fontFamily: YbsType.display, fontSize: 13, color: YbsColor.go400)),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────── ScoreRing (feedback/ScoreRing.jsx)
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 96, this.label});

  final int score;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    final color = clamped >= 80
        ? YbsColor.gold400
        : clamped >= 50
            ? YbsColor.go500
            : YbsColor.live500;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _RingPainter(fraction: clamped / 100, color: color)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$clamped',
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: size * 0.3, fontWeight: FontWeight.w600, height: 1, color: YbsColor.textHero)),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(label!, style: const TextStyle(fontFamily: YbsType.body, fontSize: 11, color: YbsColor.textSub)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - 12) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = YbsColor.borderSoft;
    canvas.drawCircle(center, r, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

// ─────────────────────────────────────────────────────────── VerdictBanner (feedback/VerdictBanner.jsx)
class VerdictBanner extends StatelessWidget {
  const VerdictBanner({super.key, required this.victory, this.title, this.subtitle});

  final bool victory;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = victory ? YbsColor.gold400 : YbsColor.live500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(victory ? 'WIN' : 'LOSE',
            style: TextStyle(
                fontSize: YbsType.micro,
                fontWeight: FontWeight.w700,
                letterSpacing: YbsType.labelTracking(YbsType.micro),
                color: victory ? YbsColor.gold300 : YbsColor.live400)),
        const SizedBox(height: YbsSpace.s2 + 2),
        Transform.rotate(
          angle: -3 * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: victory ? YbsColor.goldGlow : YbsColor.liveGlow, blurRadius: 28)],
            ),
            child: Text(title ?? (victory ? '승리' : '패배'),
                style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.1, color: color)),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: YbsSpace.s2 + 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5, color: YbsColor.textSub)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── RubricScore (feedback/RubricScore.jsx)
class RubricScore extends StatelessWidget {
  const RubricScore({super.key, required this.label, required this.score, this.max = 5, this.comment});

  final String label;
  final int score;
  final int max;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? YbsColor.go500
        : score >= 3
            ? YbsColor.amber400
            : YbsColor.live500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
            ),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '$score', style: TextStyle(color: color)),
                TextSpan(text: '/$max', style: const TextStyle(color: YbsColor.textFaint)),
              ]),
              style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.sub, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < max; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i < score ? color : YbsColor.surfaceInset,
                    border: i < score ? null : Border.all(color: YbsColor.borderSoft),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        if (comment != null) ...[
          const SizedBox(height: 6),
          Text(comment!, style: const TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── StreakBadge (feedback/StreakBadge.jsx)
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.count, this.label = '연승'});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hot = count >= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4 - 2, vertical: YbsSpace.s2),
      decoration: BoxDecoration(
        color: hot ? YbsColor.gold400.withValues(alpha: 0.12) : YbsColor.surfaceCard,
        border: Border.all(color: hot ? YbsColor.gold500 : YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.full),
        boxShadow: hot ? [BoxShadow(color: YbsColor.goldGlow, blurRadius: 20)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 18, color: hot ? YbsColor.gold400 : YbsColor.textFaint),
          const SizedBox(width: YbsSpace.s2),
          Text('$count',
              style: TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: YbsType.bodyLg,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: hot ? YbsColor.gold300 : YbsColor.textBody)),
          const SizedBox(width: YbsSpace.s2),
          Text(label, style: const TextStyle(fontSize: 13, color: YbsColor.textSub)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── HighlightCard (feedback/HighlightCard.jsx)
class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.quote, this.context_, this.score, this.bossName, this.date});

  final String quote;
  final String? context_;
  final int? score;
  final String? bossName;
  final String? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        color: YbsColor.ink900,
        gradient: RadialGradient(
          center: const Alignment(0.6, -1),
          radius: 1.1,
          colors: [YbsColor.gold400.withValues(alpha: 0.10), YbsColor.ink900],
        ),
        border: Border.all(color: YbsColor.borderStrong),
        borderRadius: BorderRadius.circular(YbsRadius.lg),
        boxShadow: YbsShadow.pop,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('오늘의 하이라이트',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: YbsType.labelTracking(11),
                      color: YbsColor.gold300)),
              if (score != null)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$score'),
                    const TextSpan(text: '점', style: TextStyle(fontSize: 11, color: YbsColor.textFaint)),
                  ]),
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 15, fontWeight: FontWeight.w600, color: YbsColor.gold400),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: Text('“$quote”',
                style: const TextStyle(fontFamily: YbsType.display, fontSize: 23, height: 1.3, color: YbsColor.textHero)),
          ),
          if (context_ != null)
            Text(context_!, style: const TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('여보세요', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.sub, color: YbsColor.textSub)),
                Row(children: [
                  if (bossName != null)
                    Text('vs $bossName  ', style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 11, color: YbsColor.textFaint)),
                  if (date != null)
                    Text('$date  ', style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 11, color: YbsColor.textFaint)),
                  const Icon(Icons.share_outlined, size: 13, color: YbsColor.textFaint),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════ 통화(라이브 레지스터) 컴포넌트

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
    final bubble = isBoss ? YbsColor.live500.withValues(alpha: 0.10) : YbsColor.go500.withValues(alpha: 0.08);
    final borderColor = active
        ? (isBoss ? YbsColor.live600 : YbsColor.go600)
        : YbsColor.borderIncall;
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

// ─────────────────────────────────────────────────────────── HudPanel (desktop in-call only)
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
      HudTone.neutral => (YbsColor.borderIncall, YbsColor.textSub, null),
      HudTone.live => (YbsColor.borderIncall, YbsColor.live500, null),
      HudTone.go => (YbsColor.go600, YbsColor.go500, YbsColor.goGlow),
      HudTone.gold => (YbsColor.gold500, YbsColor.gold400, YbsColor.goldGlow),
    };
    return Container(
      decoration: BoxDecoration(
        color: YbsColor.surfaceIncall,
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
      CallButtonKind.endCall => (YbsColor.live500.withValues(alpha: 0.08), YbsColor.borderIncall, YbsColor.live400),
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
          color: YbsColor.bgIncall,
          borderRadius: BorderRadius.circular(YbsLayout.stagePhoneRadius),
          border: Border.all(color: YbsColor.borderStrong),
          boxShadow: [
            ...YbsShadow.pop,
            BoxShadow(color: YbsColor.live500.withValues(alpha: 0.12), blurRadius: 40),
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
        color: YbsColor.surfaceIncall,
        border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
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
