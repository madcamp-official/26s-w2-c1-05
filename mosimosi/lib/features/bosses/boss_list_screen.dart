import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/player_records.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.1 보스 도감 "진상 도감" — 디자인 E 섹션 이식.
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

  // 실보스 6종 (1→chicken … 6→refund). 격파·캡션은 progress에서 계산.
  static const _entries = [
    _Entry(1, 'chicken', '야식은 치킨이지', '주문 폭주에도 흔들림 없는 자', false, ''),
    _Entry(2, 'dental', '아야야 이가 아파요', '예약 한 통이 이렇게 힘들 줄이야', false, ''),
    _Entry(3, 'alba', '시급 협상 대작전!', '오늘도 다음에 얘기하자는 사장', false, ''),
    _Entry(4, 'prof_grade', '교수님, 학점이 이상해요!', '성적엔 이유가 있다는 자', false, ''),
    _Entry(5, 'prof_gradschool', '대학원생이 될 수는 없어', 'ㅎㅎ로 거절을 막아서는 자', false, ''),
    _Entry(6, 'refund', '아니 환불이 안 된다고?', '환불은 안 됩니다', false, ''),
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
    const suffix = '';
    final progress = _progress;
    if (progress == null) return '…'; // 로딩/연결 실패
    final p = progress[e.id];
    if (p == null) return '미도전$suffix';
    if (p.cleared) return '최고 ${p.bestScore ?? 0}점 · 격파$suffix';
    if (p.bestScore != null) return '최고 ${p.bestScore}점 · 미격파$suffix';
    return '도전 ${p.attempts}회 · 미격파$suffix';
  }

  String get _clearedLabel => '격파 ${_progress == null ? '–' : _clearedCount}/6';

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
                          locked: e.locked,
                          cleared: _cleared(e),
                          imageAsset: 'assets/bossimg/boss${e.no}.png',
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
            widthFactor: _clearedCount / 6,
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
        Text('진상 도감',
            style: TextStyle(fontFamily: YbsType.display, fontSize: desktop ? YbsType.displaySize : 26, height: 1.15, color: YbsColor.white)),
        const SizedBox(height: 6),
        const Text('전화로 만난 진상들. 격파하고 수집하세요.',
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
            const Text('진상 도감',
                style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.15, color: YbsColor.white)),
            Text(_clearedLabel,
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('전화로 만난 진상들. 격파하고 수집하세요.', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s2 + 2),
        _progressBar(),
      ],
    );
  }

}

class _Entry {
  const _Entry(this.no, this.id, this.name, this.title, this.locked, this.stubCaption);
  final int no;
  final String? id; // null = 비주얼 스텁
  final String name;
  final String title;
  final bool locked;
  final String stubCaption; // 스텁 전용 (실보스는 progress에서 계산)
}
