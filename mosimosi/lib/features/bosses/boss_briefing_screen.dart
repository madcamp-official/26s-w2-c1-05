import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/bosses.dart';
import '../../ui/theme.dart';

/// 2.2 브리핑 — 시나리오·클리어 조건·제한 시간 + [발신].
/// 통화 플로우(FSD 3.1.2 ①)의 진입점. 최고 기록 등은 전적(P1.5)에서.
class BossBriefingScreen extends StatelessWidget {
  const BossBriefingScreen({super.key, required this.bossId});

  final String bossId;

  @override
  Widget build(BuildContext context) {
    final boss = bossById(bossId);
    if (boss == null) {
      return Scaffold(
        body: Center(child: Text('알 수 없는 보스: $bossId', style: const TextStyle(color: YbsColor.textSub))),
      );
    }
    final mm = boss.timeLimit.inMinutes.toString().padLeft(2, '0');
    final ss = (boss.timeLimit.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(YbsSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: YbsSpace.s4),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: YbsColor.surfaceInset,
                    border: Border.all(color: YbsColor.live600, width: 2),
                    boxShadow: [BoxShadow(color: YbsColor.live500.withValues(alpha: 0.22), blurRadius: 24)],
                  ),
                  alignment: Alignment.center,
                  child: Text(boss.portraitSyllable,
                      style: const TextStyle(fontFamily: YbsType.display, fontSize: 40, height: 1, color: YbsColor.live400)),
                ),
              ),
              const SizedBox(height: YbsSpace.s4),
              Text(boss.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, color: YbsColor.textHero)),
              const SizedBox(height: YbsSpace.s1),
              Text(boss.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
              const SizedBox(height: YbsSpace.s6),
              Container(
                padding: const EdgeInsets.all(YbsSpace.s4),
                decoration: BoxDecoration(
                  color: YbsColor.surfaceCard,
                  border: Border.all(color: YbsColor.borderSoft),
                  borderRadius: BorderRadius.circular(YbsRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('용건', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textFaint)),
                    const SizedBox(height: YbsSpace.s1),
                    Text(boss.scenario, style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
                    const SizedBox(height: YbsSpace.s4),
                    const Text('클리어 조건', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textFaint)),
                    const SizedBox(height: YbsSpace.s1),
                    for (final c in boss.clearConditions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: YbsSpace.s1),
                        child: Text('· $c', style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textBody)),
                      ),
                    const SizedBox(height: YbsSpace.s4),
                    Text('제한 시간 $mm:$ss',
                        style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.sub, color: YbsColor.textSub)),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: YbsColor.go500,
                  foregroundColor: YbsColor.textOnGo,
                  minimumSize: const Size.fromHeight(YbsSpace.hitCall - 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YbsRadius.lg)),
                ),
                onPressed: () => context.go('/bosses/${boss.id}/call'),
                icon: const Icon(Icons.call),
                label: const Text('발신', style: TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
