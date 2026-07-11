import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 2.1 보스 도감 "전설의 진상 도감" — 모바일 2열 / 데스크톱 4~5열 그리드.
/// FSD 3.1.1 초기 라인업 8종. 실데이터는 시드 3종(치킨/치과/환불)뿐이라
/// 나머지 5종은 비주얼 스텁(잠김). 해금/클리어 상태는 영속화 전 목.
class BossListScreen extends StatelessWidget {
  const BossListScreen({super.key});

  static const _entries = [
    _Entry(1, 'chicken', '무던한 치킨집 사장님', '치', '배달 주문', 1, _Tier.normal, _State.cleared),
    _Entry(2, null, '바쁜 미용실 원장', '바', '예약 잡기', 2, _Tier.normal, _State.locked),
    _Entry(3, 'dental', '따발총 치과 접수원', '따', '진료 예약 + 보험', 3, _Tier.rare, _State.unlocked),
    _Entry(4, null, '한숨 쉬는 공무원', '한', '서류 발급 문의', 3, _Tier.rare, _State.locked),
    _Entry(5, null, '말 끊는 거래처 부장', '말', '업무 일정 조율', 4, _Tier.boss, _State.locked),
    _Entry(6, null, '예약 멋대로 바꾼 미용실', '예', '항의 + 재조정', 4, _Tier.boss, _State.locked),
    _Entry(7, null, '반말하는 사장님', '반', '급여 문의', 4, _Tier.boss, _State.locked),
    _Entry(8, 'refund', '환불 불가 3연벙 상담원', '환', '환불 요구', 5, _Tier.legend, _State.unlocked),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const YbsHeader(title: '전설의 진상 도감'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 1200 ? 5 : c.maxWidth >= 900 ? 4 : c.maxWidth >= 640 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(YbsSpace.s5),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: YbsSpace.s4,
                      crossAxisSpacing: YbsSpace.s4,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) => _BossCard(entry: _entries[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Tier { normal, rare, boss, legend }

enum _State { locked, unlocked, cleared }

class _Entry {
  const _Entry(this.no, this.id, this.name, this.syllable, this.scenario, this.difficulty, this.tier, this.state);
  final int no;
  final String? id; // null = 비주얼 스텁 (미구현 보스)
  final String name;
  final String syllable;
  final String scenario;
  final int difficulty; // 1~5
  final _Tier tier;
  final _State state;
}

class _BossCard extends StatelessWidget {
  const _BossCard({required this.entry});

  final _Entry entry;

  Color get _tierColor => switch (entry.tier) {
        _Tier.normal => YbsColor.ink300,
        _Tier.rare => YbsColor.sky400,
        _Tier.boss => YbsColor.live500,
        _Tier.legend => YbsColor.gold400,
      };

  @override
  Widget build(BuildContext context) {
    final locked = entry.state == _State.locked || entry.id == null;
    final card = Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: locked ? YbsColor.borderSoft : _tierColor.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(YbsRadius.lg),
        boxShadow: [
          ...YbsShadow.card,
          if (!locked) BoxShadow(color: _tierColor.withValues(alpha: 0.15), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('No.${entry.no.toString().padLeft(3, '0')}',
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.textFaint)),
              const Spacer(),
              if (entry.state == _State.cleared)
                Transform.rotate(
                  angle: -0.07,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s2, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: YbsColor.gold400, width: 1.5),
                      borderRadius: BorderRadius.circular(YbsRadius.xs),
                    ),
                    child: const Text('격파',
                        style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.micro, color: YbsColor.gold400)),
                  ),
                ),
              if (locked) const Icon(Icons.lock, size: 14, color: YbsColor.textFaint),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: YbsColor.surfaceInset,
                border: Border.all(color: locked ? YbsColor.ink600 : _tierColor, width: 2),
                gradient: locked
                    ? null
                    : RadialGradient(colors: [_tierColor.withValues(alpha: 0.22), Colors.transparent]),
              ),
              alignment: Alignment.center,
              child: Text(locked ? '?' : entry.syllable,
                  style: TextStyle(
                      fontFamily: YbsType.display,
                      fontSize: 24,
                      height: 1,
                      color: locked ? YbsColor.textFaint : _tierColor)),
            ),
          ),
          const Spacer(),
          Text(locked ? '???' : entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: YbsType.sub,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: locked ? YbsColor.textFaint : YbsColor.textHero)),
          const SizedBox(height: 2),
          Text(entry.scenario, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s2),
          Row(children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < entry.difficulty ? _tierColor : YbsColor.ink600,
                  ),
                ),
              ),
          ]),
        ],
      ),
    );

    if (locked) return Opacity(opacity: 0.75, child: card);
    return GestureDetector(onTap: () => context.go('/bosses/${entry.id}'), child: card);
  }
}
