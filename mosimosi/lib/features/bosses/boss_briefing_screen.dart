import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/bosses.dart';
import '../../core/models/boss.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.2 미션 브리핑 — 디자인 F 섹션 이식.
/// 모바일 세로 / 데스크톱 중앙 760px 집중(과확장 금지). 최고 기록은 목.
class BossBriefingScreen extends StatelessWidget {
  const BossBriefingScreen({super.key, required this.bossId});

  final String bossId;

  static const _bestScores = {'chicken': '92점', 'dental': '81점', 'refund': '87점'}; // 목

  (Color, Color) _tierColors(Boss boss) => switch (boss.tier) {
        BossTier.normal => (YbsColor.ink300, YbsColor.ink300.withValues(alpha: 0.22)),
        BossTier.rare => (YbsColor.sky400, YbsColor.sky400.withValues(alpha: 0.22)),
        BossTier.boss => (YbsColor.live500, YbsColor.live500.withValues(alpha: 0.22)),
        BossTier.legend => (YbsColor.gold400, YbsColor.gold400.withValues(alpha: 0.22)),
      };

  @override
  Widget build(BuildContext context) {
    final boss = bossById(bossId);
    if (boss == null) {
      return Scaffold(
        body: Center(child: Text('알 수 없는 보스: $bossId', style: const TextStyle(color: YbsColor.textSub))),
      );
    }
    final desktop = isDesktop(context);
    return Scaffold(
      body: SafeArea(
        child: desktop ? _desktop(context, boss) : _mobile(context, boss),
      ),
    );
  }

  // ================================================================ mobile
  Widget _mobile(BuildContext context, Boss boss) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/bosses'),
                child: const Icon(Icons.chevron_left, size: 24, color: YbsColor.textSub),
              ),
              Expanded(child: Center(child: _missionLabel(boss))),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: YbsSpace.s5),
                _portraitBlock(boss, center: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
                  child: _situationCard(boss),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
                  child: _conditionsCard(boss),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
                  child: Row(children: [
                    Expanded(child: _statCard('제한 시간', _limit(boss), YbsColor.textHero)),
                    const SizedBox(width: YbsSpace.s2 + 2),
                    Expanded(child: _statCard('최고 기록 · 도전 2회', _bestScores[boss.id] ?? '—', YbsColor.gold400)),
                  ]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 30),
          child: _callCta(context, boss),
        ),
      ],
    );
  }

  // ================================================================ desktop (중앙 760px)
  Widget _desktop(BuildContext context, Boss boss) {
    final (tierColor, tierSpot) = _tierColors(boss);
    return Center(
      child: SizedBox(
        width: 760,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _portrait(boss, size: 96, syllableSize: 42, tierColor: tierColor, tierSpot: tierSpot),
              const SizedBox(width: YbsSpace.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _missionLabel(boss),
                    const SizedBox(height: 6),
                    Text(boss.name,
                        style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.15, color: YbsColor.textHero)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('「${boss.quote}」', style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
                      const SizedBox(width: YbsSpace.s3),
                      DifficultyMeter(level: boss.difficultyLevel),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: YbsSpace.s5),
            // IntrinsicHeight: 부모 Column이 이 Row에 무한 높이를 주므로
            // (mainAxisSize.max + 언바운드 컨텍스트), stretch가 자식에 강제할
            // 유한한 기준 높이가 필요 — 두 카드를 콘텐츠 기준 동일 높이로.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardLabel('상황'),
                          const SizedBox(height: YbsSpace.s2),
                          _scenarioText(boss),
                          const Spacer(),
                          Row(children: [
                            _inlineStat('제한 시간', _limit(boss), YbsColor.textHero),
                            const SizedBox(width: YbsSpace.s5),
                            _inlineStat('최고 기록 · 도전 2회', _bestScores[boss.id] ?? '—', YbsColor.gold400),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: YbsSpace.s4),
                  Expanded(child: _conditionsCard(boss)),
                ],
              ),
            ),
            const SizedBox(height: YbsSpace.s6),
            Center(child: SizedBox(width: 360, child: _callCta(context, boss))),
          ],
        ),
      ),
    );
  }

  // ================================================================ pieces
  Widget _missionLabel(Boss boss) {
    final suffix = boss.tier == BossTier.legend ? ' · 최종 보스' : '';
    return Text('MISSION No.${boss.number.toString().padLeft(3, '0')}$suffix',
        style: TextStyle(
            fontFamily: YbsType.numeric,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: YbsType.labelTracking(11),
            color: YbsColor.gold400));
  }

  Widget _portraitBlock(Boss boss, {required bool center}) {
    final (tierColor, tierSpot) = _tierColors(boss);
    return Column(
      children: [
        _portrait(boss, size: 96, syllableSize: 42, tierColor: tierColor, tierSpot: tierSpot),
        const SizedBox(height: YbsSpace.s2 + 2),
        Text(boss.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: YbsType.display, fontSize: 28, height: 1.2, color: YbsColor.textHero)),
        const SizedBox(height: 4),
        Text('「${boss.quote}」', style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s2 + 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DifficultyMeter(level: boss.difficultyLevel),
            const SizedBox(width: YbsSpace.s2 + 2),
            if (boss.tier == BossTier.legend)
              const YbsBadge(label: '전설', tone: BadgeTone.gold)
            else if (boss.tier == BossTier.boss)
              const YbsBadge(label: '보스', tone: BadgeTone.live)
            else if (boss.tier == BossTier.rare)
              Text('희귀', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro), color: tierColor))
            else
              Text('일반', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro), color: tierColor)),
          ],
        ),
      ],
    );
  }

  Widget _portrait(Boss boss, {required double size, required double syllableSize, required Color tierColor, required Color tierSpot}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: YbsColor.surfaceInset,
        gradient: RadialGradient(center: const Alignment(0, -0.24), radius: 0.72, colors: [tierSpot, Colors.transparent]),
        border: Border.all(color: tierColor.withValues(alpha: 0.8), width: 2),
        boxShadow: [BoxShadow(color: tierColor.withValues(alpha: 0.35), blurRadius: 28)],
      ),
      alignment: Alignment.center,
      child: Text(boss.portraitSyllable,
          style: TextStyle(fontFamily: YbsType.display, fontSize: syllableSize, height: 1, color: tierColor)),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(YbsSpace.s5),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        ),
        child: child,
      );

  Widget _cardLabel(String label) => Text(label,
      style: TextStyle(
          fontSize: YbsType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: YbsType.labelTracking(YbsType.micro) / 2,
          color: YbsColor.textFaint));

  Widget _scenarioText(Boss boss) => Text(boss.scenario,
      style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody));

  Widget _situationCard(Boss boss) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_cardLabel('상황'), const SizedBox(height: 6), _scenarioText(boss)],
        ),
      );

  Widget _conditionsCard(Boss boss) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardLabel('달성 조건'),
            const SizedBox(height: YbsSpace.s3),
            for (final c in boss.clearConditions)
              Padding(
                padding: const EdgeInsets.only(bottom: YbsSpace.s3),
                child: Row(children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: YbsColor.ink500, width: 2)),
                  ),
                  const SizedBox(width: YbsSpace.s2 + 2),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody))),
                ]),
              ),
          ],
        ),
      );

  Widget _statCard(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4 - 2, vertical: YbsSpace.s3),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: YbsColor.textFaint)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyLg, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );

  Widget _inlineStat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: YbsColor.textFaint)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyLg, fontWeight: FontWeight.w600, color: color)),
        ],
      );

  String _limit(Boss boss) {
    final mm = boss.timeLimit.inMinutes.toString().padLeft(2, '0');
    final ss = (boss.timeLimit.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _callCta(BuildContext context, Boss boss) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => context.go('/bosses/${boss.id}/call'),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: YbsColor.go500,
              borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
              boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 24), BoxShadow(color: YbsColor.go600, spreadRadius: 1)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.call, size: 22, color: YbsColor.textOnGo),
                SizedBox(width: YbsSpace.s2 + 2),
                Text('발신',
                    style: TextStyle(fontFamily: YbsType.body, fontSize: 19, fontWeight: FontWeight.w800, color: YbsColor.textOnGo)),
              ],
            ),
          ),
        ),
        const SizedBox(height: YbsSpace.s2 + 2),
        const Center(
          child: Text('연결되면 바로 시작돼요. 심호흡 한 번.',
              style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
        ),
      ],
    );
  }
}
