import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.1 보스 도감 "전설의 진상 도감" — 디자인 E 섹션 이식.
/// 모바일 2열 / 데스크톱 4열 + 필터 칩. 8종 중 실데이터는 시드 3종
/// (No.001/002/008 → 탭 시 브리핑), 나머지는 비주얼 스텁. 상태는 목.
class BossListScreen extends StatelessWidget {
  const BossListScreen({super.key});

  // 디자인 데이터 이식 (실보스 매핑: 1→chicken, 2→dental, 8→refund).
  static const _entries = [
    _Entry(1, 'chicken', '무던한 치킨집 사장님', '주문 폭주에도 흔들림 없는 자', BossTierUi.normal, 1, false, true, '최고 92점 · 격파'),
    _Entry(2, 'dental', '따발총 치과 접수원', '3초에 한 문장, 숨 쉴 틈 없음', BossTierUi.normal, 2, false, true, '최고 81점 · 격파'),
    _Entry(3, null, '단호한 미용실 원장', '예약장부의 절대 지배자', BossTierUi.normal, 2, false, true, '최고 76점 · 격파'),
    _Entry(4, null, '말 끊는 김 과장', '문장을 끝까지 들어본 적 없는 자', BossTierUi.rare, 3, false, false, '최고 71점 · 미격파'),
    _Entry(5, null, '되묻는 보험 설계사', '', BossTierUi.rare, 3, true, false, '해금: No.004 격파 · 소문: 전화가 끝나지 않는다'),
    _Entry(6, null, '', '', BossTierUi.rare, 4, true, false, '해금: No.005 격파 · 소문: 서류를 세 번 요구한다'),
    _Entry(7, null, '', '', BossTierUi.boss, 4, true, false, '해금: No.006 격파 · 소문: 조항을 전부 외우고 있다'),
    _Entry(8, 'refund', '환불 불가 3연벙 상담원', '최종 보스 · 환불은 안 됩니다', BossTierUi.legend, 5, false, false, '최고 87점 · 미격파 · 최종 보스'),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(desktop ? 48 : YbsSpace.s5, desktop ? 40 : YbsSpace.s6, desktop ? 48 : YbsSpace.s5, 0),
              child: _header(desktop),
            ),
            if (desktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, YbsSpace.s6, 48, 0),
                child: _filterChips(),
              ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(desktop ? 48 : YbsSpace.s5).copyWith(top: YbsSpace.s4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: desktop ? 4 : 2,
                  mainAxisSpacing: desktop ? YbsSpace.s6 : YbsSpace.s3,
                  crossAxisSpacing: desktop ? YbsSpace.s6 : YbsSpace.s3,
                  childAspectRatio: 0.68,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: BossCardUi(
                          number: e.no,
                          name: e.name,
                          title: e.title,
                          tier: e.tier,
                          difficulty: e.difficulty,
                          locked: e.locked,
                          cleared: e.cleared,
                          onTap: e.id == null ? null : () => context.go('/bosses/${e.id}'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                        child: Text(e.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, height: 1.4, color: YbsColor.textFaint)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool desktop) {
    final progress = Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
      children: [
        const Text('격파 3/8',
            style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
        const SizedBox(height: YbsSpace.s2),
        SizedBox(
          width: desktop ? 280 : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(YbsRadius.full),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 3 / 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: YbsColor.live500,
                    boxShadow: [BoxShadow(color: YbsColor.liveGlow, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('전설의 진상 도감',
            style: TextStyle(fontFamily: YbsType.display, fontSize: desktop ? YbsType.displaySize : 26, height: 1.15, color: YbsColor.white)),
        const SizedBox(height: 6),
        const Text('전화로 만난 전설들. 격파하고 수집하세요.',
            style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
      ],
    );
    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [Expanded(child: titleBlock), progress],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('전설의 진상 도감',
                style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.15, color: YbsColor.white)),
            Text('격파 3/8',
                style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('전화로 만난 전설들. 격파하고 수집하세요.', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s2 + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(YbsRadius.full),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: YbsColor.surfaceInset,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 3 / 8,
              child: Container(
                decoration: BoxDecoration(
                  color: YbsColor.live500,
                  boxShadow: [BoxShadow(color: YbsColor.liveGlow, blurRadius: 12)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChips() {
    Widget chip(String label, {bool active = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: 7),
          decoration: BoxDecoration(
            color: active ? YbsColor.surfaceCardHover : Colors.transparent,
            border: Border.all(color: active ? YbsColor.borderStrong : YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.full),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? YbsColor.textHero : YbsColor.textSub)),
        );
    return Row(children: [
      chip('전체', active: true),
      const SizedBox(width: YbsSpace.s2),
      chip('미격파'),
      const SizedBox(width: YbsSpace.s2),
      chip('격파'),
      const SizedBox(width: YbsSpace.s2),
      chip('전설'),
    ]);
  }
}

class _Entry {
  const _Entry(this.no, this.id, this.name, this.title, this.tier, this.difficulty, this.locked, this.cleared, this.caption);
  final int no;
  final String? id; // null = 비주얼 스텁
  final String name;
  final String title;
  final BossTierUi tier;
  final int difficulty;
  final bool locked;
  final bool cleared;
  final String caption;
}
