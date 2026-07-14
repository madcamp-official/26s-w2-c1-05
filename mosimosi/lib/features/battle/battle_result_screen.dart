import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'battle_room.dart';

/// 3.4 판정 대기 + 3.5 배틀 판정 — 디자인 J 섹션 이식.
/// 탭 A 판정(루브릭) / 탭 B 비밀 공개(페이오프) / 탭 C 내 리포트.
/// 실배선: 서버 verdict 브로드캐스트 수신까지 대기 후 실데이터 렌더(Phase 3).
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  BattleRoomController? _room;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _room = BattleRoomController.of(widget.roomId);
    _room?.addListener(_onRoom);
  }

  void _onRoom() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoom);
    super.dispose();
  }

  void _leave(String location) {
    BattleRoomController.unregister(widget.roomId); // 방 수명 종료 (WS close)
    context.go(location);
  }

  // ---- verdict 접근 헬퍼 (서버 스키마 방어 파싱) ----
  Map<String, dynamic> get _verdict => _room?.verdict ?? const {};

  Map<String, dynamic> _player(String userId) =>
      (_verdict['players'] as Map<String, dynamic>?)?[userId] as Map<String, dynamic>? ??
      const {};

  String get _myId => _room!.myUserId;

  String get _oppId {
    final players = _verdict['players'] as Map<String, dynamic>? ?? const {};
    return players.keys.firstWhere((k) => k != _myId, orElse: () => '');
  }

  int _momentumOf(String userId) =>
      ((_verdict['momentum'] as Map<String, dynamic>?)?[userId] as num?)?.round() ?? 50;

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('배틀 세션이 만료됐어요', style: TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
              const SizedBox(height: YbsSpace.s4),
              YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
            ],
          ),
        ),
      );
    }
    if (room.verdict == null) {
      // ---- 3.4 판정 대기 (서버 최종 심판 진행 중) ----
      final stuck = room.state == 'disconnected';
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!stuck) const CircularProgressIndicator(color: YbsColor.gold400),
              const SizedBox(height: YbsSpace.s5),
              Text(stuck ? '서버와 연결이 끊겨 판정을 받지 못했어요' : '심판이 통화 전체를 검토 중…',
                  style: const TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
              const SizedBox(height: YbsSpace.s2),
              const Text('과정 점수로 판정해요 — 버티기는 안 통해요',
                  style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)),
              if (stuck) ...[
                const SizedBox(height: YbsSpace.s5),
                YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => _leave('/home')),
              ],
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
              child: Row(children: [
                Expanded(child: _tabButton('판정', 0)),
                const SizedBox(width: 6),
                Expanded(child: _tabButton('비밀 공개', 1)),
                const SizedBox(width: 6),
                Expanded(child: _tabButton('내 리포트', 2)),
              ]),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _verdictTab(room),
                1 => _secretsTab(room),
                _ => _myReportTab(room),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3 + 2, YbsSpace.s5, 30),
              child: Row(children: [
                Expanded(
                  child: YbsButton(
                    label: '재매칭',
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: () => _leave('/battle/matching'),
                  ),
                ),
                const SizedBox(width: YbsSpace.s2 + 2),
                SizedBox(
                  width: 90,
                  child: YbsButton(
                    label: '홈',
                    variant: YbsButtonVariant.ghost,
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: () => _leave('/home'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? YbsColor.surfaceCardHover : Colors.transparent,
          border: Border.all(color: active ? YbsColor.borderStrong : YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? YbsColor.textHero : YbsColor.textSub)),
      ),
    );
  }

  Widget _card({required List<Widget> children, Color? border, Color? bg, Color? glow}) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: bg ?? YbsColor.surfaceCard,
          border: Border.all(color: border ?? YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md + 2),
          boxShadow: glow == null ? null : [BoxShadow(color: glow, blurRadius: 20)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _cardLabel(String label, {Color color = YbsColor.textFaint}) => Text(label,
      style: TextStyle(
          fontSize: YbsType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: YbsType.labelTracking(YbsType.micro) / 2,
          color: color));

  List<Widget> _rubricRows(Map<String, dynamic> player) {
    final rubric = player['rubric'] as List? ?? const [];
    if (rubric.isEmpty) {
      return const [Text('루브릭 데이터가 비어 있어요.', style: TextStyle(color: YbsColor.textFaint))];
    }
    return [
      for (final (i, r) in rubric.indexed)
        if (r is Map<String, dynamic>) ...[
          if (i > 0) const SizedBox(height: YbsSpace.s4 - 2),
          RubricScore(
            label: r['label'] as String? ?? '',
            score: ((r['score'] as num?)?.round() ?? 0).clamp(0, 5),
            comment: r['comment'] as String? ?? '',
          ),
        ],
    ];
  }

  // ---- 탭 A 판정 ----
  Widget _verdictTab(BattleRoomController room) {
    final match = room.match;
    final winnerId = _verdict['winnerUserId'] as String?;
    final iWon = winnerId == _myId;
    final draw = winnerId == null || winnerId.isEmpty;
    final myMomentum = _momentumOf(_myId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
      children: [
        Center(
          child: VerdictBanner(
            victory: iWon,
            title: draw
                ? '무승부'
                : iWon
                    ? '승리'
                    : '패배',
            subtitle: (_verdict['verdictLine'] as String?)?.isNotEmpty == true
                ? _verdict['verdictLine'] as String
                : null,
          ),
        ),
        const SizedBox(height: YbsSpace.s4 + 2),
        Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('나 · ${match.roleLabel}',
                  style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go400)),
              Text('최종 기세 $myMomentum : ${100 - myMomentum}',
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
              Text(match.opponentNickname,
                  style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.live400)),
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
                widthFactor: (myMomentum / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(color: YbsColor.go500, boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)]),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: YbsSpace.s4 + 2),
        _card(children: [
          _cardLabel('나 · ${match.roleLabel} 루브릭'),
          const SizedBox(height: YbsSpace.s4 - 2),
          ..._rubricRows(_player(_myId)),
        ]),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(children: [
          _cardLabel('${match.opponentNickname} · ${match.opponentRoleLabel} 루브릭'),
          const SizedBox(height: YbsSpace.s4 - 2),
          ..._rubricRows(_player(_oppId)),
        ]),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  // ---- 탭 B 비밀 공개 ----
  Widget _secretsTab(BattleRoomController room) {
    final match = room.match;
    final me = _player(_myId);
    final opp = _player(_oppId);

    Widget resultTag(String label, {required bool good}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: good ? YbsColor.go600 : YbsColor.live600),
            borderRadius: BorderRadius.circular(YbsRadius.xs),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: good ? YbsColor.go400 : YbsColor.live400)),
        );

    Widget secretCard({
      required String title,
      required Color labelColor,
      required Color? borderColor,
      required Color bg,
      required String secret,
      required bool? achieved,
      required String note,
    }) =>
        _card(
          border: borderColor,
          bg: bg,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: _cardLabel(title, color: labelColor)),
              if (achieved != null) resultTag(achieved ? '달성' : '실패', good: achieved),
            ]),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(secret,
                style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: YbsSpace.s2),
              Text(note, style: const TextStyle(fontSize: YbsType.micro, height: 1.5, color: YbsColor.textSub)),
            ],
          ],
        );

    final keyQuote = _verdict['keyQuote'] as Map<String, dynamic>? ?? const {};
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, 26, YbsSpace.s5, 0),
      children: [
        const Center(
          child: Text('서로의 패, 공개!',
              style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.2, color: YbsColor.gold300)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('이제야 보이는 진실', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
        ),
        const SizedBox(height: YbsSpace.s5),
        secretCard(
          title: '나 · ${match.roleLabel}의 비밀 목표',
          labelColor: YbsColor.go400,
          borderColor: YbsColor.go600,
          bg: YbsColor.go500.withValues(alpha: 0.06),
          secret: match.secretGoal,
          achieved: me['goalAchieved'] as bool?,
          note: me['goalNote'] as String? ?? '',
        ),
        if (match.ruleCard != null) ...[
          const SizedBox(height: YbsSpace.s4 - 2),
          secretCard(
            title: '나의 규칙 카드',
            labelColor: YbsColor.live400,
            borderColor: YbsColor.borderIncall,
            bg: YbsColor.live500.withValues(alpha: 0.05),
            secret: match.ruleCard!,
            achieved: null,
            note: me['ruleNote'] as String? ?? '',
          ),
        ],
        const SizedBox(height: YbsSpace.s4 - 2),
        secretCard(
          title: '${match.opponentNickname} · ${match.opponentRoleLabel}의 비밀 목표',
          labelColor: YbsColor.live400,
          borderColor: YbsColor.live600,
          bg: YbsColor.live500.withValues(alpha: 0.06),
          secret: opp['secretGoal'] as String? ?? '(공개 데이터 없음)',
          achieved: opp['goalAchieved'] as bool?,
          note: opp['goalNote'] as String? ?? '',
        ),
        if ((keyQuote['text'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: YbsSpace.s4 - 2),
          _card(children: [
            _cardLabel('결정적 발언'),
            const SizedBox(height: 6),
            Text('「${keyQuote['text']}」',
                style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
            if ((keyQuote['note'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(keyQuote['note'] as String,
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 11, color: YbsColor.textFaint)),
            ],
          ]),
        ],
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  // ---- 탭 C 내 리포트 ----
  Widget _myReportTab(BattleRoomController room) {
    final me = _player(_myId);
    final improvement = me['improvement'] as Map<String, dynamic>? ?? const {};
    final keyQuote = _verdict['keyQuote'] as Map<String, dynamic>? ?? const {};
    final hasAny = improvement.isNotEmpty || (keyQuote['text'] as String?)?.isNotEmpty == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
      children: [
        if (!hasAny)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: YbsSpace.s6),
              child: Text('리포트 데이터가 비어 있어요.', style: TextStyle(color: YbsColor.textFaint)),
            ),
          ),
        if ((keyQuote['text'] as String?)?.isNotEmpty == true)
          _card(children: [
            _cardLabel('결정적 발언'),
            const SizedBox(height: 6),
            Text('「${keyQuote['text']}」',
                style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
          ]),
        if (improvement.isNotEmpty) ...[
          const SizedBox(height: YbsSpace.s4 - 2),
          _card(
            border: YbsColor.gold500,
            bg: YbsColor.gold400.withValues(alpha: 0.05),
            children: [
              _cardLabel('이렇게 말했다면', color: YbsColor.gold300),
              const SizedBox(height: YbsSpace.s2 + 2),
              Text('「${improvement['situation'] ?? ''}」',
                  style: const TextStyle(fontSize: 13, color: YbsColor.textFaint, decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 4),
              Text('→ 「${improvement['better'] ?? ''}」',
                  style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textBody)),
            ],
          ),
        ],
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }
}
