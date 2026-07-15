import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/player_records.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.1 보스 도감 "전설의 진상 도감" — 디자인 E 섹션 이식.
/// 모바일 2열 / 데스크톱 4열 + 필터 칩. 8종 중 실데이터는 시드 6종
/// (No.001/002/003/004/005/008 → 탭 시 브리핑), 나머지는 비주얼 스텁.
/// 격파·최고점은 GET /users/{id}/progress 실데이터 (Phase 2 §5).
class BossListScreen extends StatefulWidget {
  const BossListScreen({super.key});

  @override
  State<BossListScreen> createState() => _BossListScreenState();
}

class _BossListScreenState extends State<BossListScreen> {
  /// null = 로딩 중/연결 실패 (미도전과 구분 — 캡션 '…' 표시).
  Map<String, BossProgress>? _progress;

  // 비주얼 데이터 (실보스 매핑: 1→chicken, 2→dental, 3→alba, 4→prof_grade,
  // 5→prof_gradschool, 8→refund).
  // 실보스의 격파·캡션은 progress에서 계산, 스텁(6~7)은 고정 문구.
  static const _entries = [
    _Entry(1, 'chicken', '무던한 치킨집 사장님', '주문 폭주에도 흔들림 없는 자', BossTierUi.normal, 1, false, ''),
    _Entry(2, 'dental', '따발총 치과 접수원', '3초에 한 문장, 숨 쉴 틈 없음', BossTierUi.normal, 2, false, ''),
    _Entry(3, 'alba', '미루기 달인 알바 사장님', '오늘도 다음에 얘기하자는 사장', BossTierUi.rare, 3, false, ''),
    _Entry(4, 'prof_grade', '출석부 든 교수님', '성적엔 이유가 있다는 자', BossTierUi.rare, 4, false, ''),
    _Entry(5, 'prof_gradschool', '칭찬으로 붙잡는 교수님', 'ㅎㅎ로 거절을 막아서는 자', BossTierUi.boss, 4, false, ''),
    _Entry(6, null, '', '', BossTierUi.rare, 4, true, '해금: No.005 격파 · 소문: 서류를 세 번 요구한다'),
    _Entry(7, null, '', '', BossTierUi.boss, 4, true, '해금: No.006 격파 · 소문: 조항을 전부 외우고 있다'),
    _Entry(8, 'refund', '환불 불가 3연벙 상담원', '최종 보스 · 환불은 안 됩니다', BossTierUi.legend, 5, false, ''),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    recordsVersion.addListener(_load); // 판 종료 보고 후 재조회 (셸 탭 유지 대응)
  }

  @override
  void dispose() {
    recordsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final progress = await fetchProgress();
      if (mounted) setState(() => _progress = progress);
    } catch (_) {
      // 연결 실패 — 캡션 '…' 유지 (잘못된 '미도전' 표시 방지).
    }
  }

  bool _cleared(_Entry e) =>
      e.id != null && (_progress?[e.id]?.cleared ?? false);

  int get _clearedCount =>
      _entries.where(_cleared).length;

  String _caption(_Entry e) {
    if (e.id == null) return e.stubCaption; // 비주얼 스텁
    final suffix = e.no == 8 ? ' · 최종 보스' : '';
    final progress = _progress;
    if (progress == null) return '…'; // 로딩/연결 실패
    final p = progress[e.id];
    if (p == null) return '미도전$suffix';
    if (p.cleared) return '최고 ${p.bestScore ?? 0}점 · 격파$suffix';
    if (p.bestScore != null) return '최고 ${p.bestScore}점 · 미격파$suffix';
    return '도전 ${p.attempts}회 · 미격파$suffix';
  }

  String get _clearedLabel => '격파 ${_progress == null ? '–' : _clearedCount}/8';

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
                          cleared: _cleared(e),
                          onTap: e.id == null ? null : () => context.go('/bosses/${e.id}'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                        child: Text(_caption(e),
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

  Widget _progressBar() => ClipRRect(
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
            widthFactor: _clearedCount / 8,
            child: Container(
              decoration: BoxDecoration(
                color: YbsColor.live500,
                boxShadow: [BoxShadow(color: YbsColor.liveGlow, blurRadius: 12)],
              ),
            ),
          ),
        ),
      );

  Widget _header(bool desktop) {
    final progress = Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
      children: [
        Text(_clearedLabel,
            style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
        const SizedBox(height: YbsSpace.s2),
        SizedBox(width: desktop ? 280 : null, child: _progressBar()),
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
          children: [
            const Text('전설의 진상 도감',
                style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.15, color: YbsColor.white)),
            Text(_clearedLabel,
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('전화로 만난 전설들. 격파하고 수집하세요.', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s2 + 2),
        _progressBar(),
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
  const _Entry(this.no, this.id, this.name, this.title, this.tier, this.difficulty, this.locked, this.stubCaption);
  final int no;
  final String? id; // null = 비주얼 스텁
  final String name;
  final String title;
  final BossTierUi tier;
  final int difficulty;
  final bool locked;
  final String stubCaption; // 스텁 전용 (실보스는 progress에서 계산)
}
