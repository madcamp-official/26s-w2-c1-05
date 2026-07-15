import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/sound_service.dart';
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
  bool _resultSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    // 결과는 배틀의 연장 — 로비로 돌아갈 때까지 BGM을 계속 음소거한다.
    SoundService.instance.suppressBgm();
    _room = BattleRoomController.of(widget.roomId);
    _room?.addListener(_onRoom);
    _maybePlayResultSound(); // verdict가 이미 도착해 있으면 즉시
  }

  void _onRoom() {
    _maybePlayResultSound();
    if (mounted) setState(() {});
  }

  /// verdict 도착 시 승/패 효과음 1회 (무승부는 무음).
  void _maybePlayResultSound() {
    if (_resultSoundPlayed || _room?.verdict == null) return;
    _resultSoundPlayed = true;
    final winnerId = _verdict['winnerUserId'] as String?;
    if (winnerId == null) return; // 무승부
    if (winnerId == _myId) {
      SoundService.instance.success();
    } else {
      SoundService.instance.failure();
    }
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoom);
    SoundService.instance.unsuppressBgm();
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
          _cardLabel('${match.opponentNickname} · ${match.opponentLabel} 루브릭'),
          const SizedBox(height: YbsSpace.s4 - 2),
          ..._rubricRows(_player(_oppId)),
        ]),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  // ---- 탭 B 비밀 공개 (4c) — 나 vs 상대 비교 + 선/비밀 플래그 ----
  Widget _secretsTab(BattleRoomController room) {
    final me = _player(_myId);
    final opp = _player(_oppId);
    final winnerId = _verdict['winnerUserId'] as String?;
    final summary = _verdict['settlementSummary'] as String? ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, 26, YbsSpace.s5, 0),
      children: [
        const Center(
          child: Text('서로의 패, 공개!',
              style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.2, color: YbsColor.gold300)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(summary.isNotEmpty ? '최종 합의 · $summary' : '두 사람의 비밀이 모두 공개됐어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: YbsColor.textSub)),
        ),
        const SizedBox(height: YbsSpace.s5),
        _revealCard(me, mine: true, won: winnerId != null && winnerId == _myId, draw: winnerId == null),
        const SizedBox(height: YbsSpace.s3),
        const Center(child: Text('VS', style: TextStyle(fontFamily: YbsType.display, fontSize: 16, color: YbsColor.live500))),
        const SizedBox(height: YbsSpace.s3),
        _revealCard(opp, mine: false, won: winnerId != null && winnerId == _oppId, draw: winnerId == null),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  Widget _flagRow(String text, {required bool good}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(good ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
              size: 15, color: good ? YbsColor.go400 : YbsColor.live400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4, color: good ? YbsColor.go300 : YbsColor.live400)),
          ),
        ],
      );

  Widget _fieldRow(String tag, Color tagColor, Color tagBg, String text, {bool strike = false}) => Padding(
        padding: const EdgeInsets.only(bottom: YbsSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(YbsRadius.xs)),
              child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tagColor)),
            ),
            const SizedBox(width: YbsSpace.s2 + 2),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: strike ? YbsColor.textFaint : YbsColor.textBody,
                      decoration: strike ? TextDecoration.lineThrough : null)),
            ),
          ],
        ),
      );

  /// 한쪽(나/상대)의 공개 카드 — 목표·선(지켜냄/넘음)·비밀(들킴/안들킴).
  Widget _revealCard(Map<String, dynamic> p, {required bool mine, required bool won, required bool draw}) {
    final label = p['label'] as String? ?? '';
    final goal = p['goal'] as String? ?? '';
    final hardLine = p['hardLine'] as String? ?? '';
    final secret = p['secret'] as String? ?? '';
    final crossed = p['crossedLine'] as bool?;
    final exposed = p['secretExposed'] as bool?;
    final accent = mine ? YbsColor.go400 : YbsColor.live400;
    final border = mine ? YbsColor.go600 : YbsColor.live600;
    // 실제 닉네임 우선 (서버 verdict.players[uid].nickname). 역할 슬롯(agent/claimant)이
    // 새어나오지 않도록 nickname → 없으면 '나'/상대 닉으로 폴백.
    final nick = (p['nickname'] as String?)?.trim();
    final who = (nick != null && nick.isNotEmpty) ? nick : (mine ? '나' : _room!.match.opponentNickname);
    final title = label.isEmpty ? who : '$who · $label';
    final tag = draw ? 'DRAW' : (won ? 'WIN' : 'LOSE');
    return _card(
      border: border,
      bg: (mine ? YbsColor.go500 : YbsColor.live500).withValues(alpha: 0.05),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: won ? YbsColor.gold500 : YbsColor.borderStrong),
                borderRadius: BorderRadius.circular(YbsRadius.xs),
              ),
              child: Text(tag,
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w700, color: won ? YbsColor.gold400 : YbsColor.textFaint)),
            ),
          ],
        ),
        const SizedBox(height: YbsSpace.s3),
        _fieldRow('목표', YbsColor.go400, YbsColor.go500.withValues(alpha: 0.10), goal),
        Container(
          margin: const EdgeInsets.only(top: 2, bottom: YbsSpace.s2),
          padding: const EdgeInsets.all(YbsSpace.s3),
          decoration: BoxDecoration(color: YbsColor.surfaceInset, borderRadius: BorderRadius.circular(YbsRadius.sm + 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldRow('선', YbsColor.live400, YbsColor.live500.withValues(alpha: 0.12), hardLine, strike: crossed == true),
              if (crossed != null) _flagRow(crossed ? '물러설 수 없는 선을 넘음 — 자동 패배' : '물러설 수 없는 선 지켜냄', good: !crossed),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(YbsSpace.s3),
          decoration: BoxDecoration(
            color: const Color(0xFF16130A),
            border: Border.all(color: YbsColor.gold500),
            borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldRow('비밀', YbsColor.gold300, YbsColor.gold400.withValues(alpha: 0.12), secret),
              if (exposed != null) _flagRow(exposed ? '비밀 들킴 — 상대가 정확히 짚음' : '비밀 안 들킴 — 주도권 유지', good: !exposed),
            ],
          ),
        ),
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
