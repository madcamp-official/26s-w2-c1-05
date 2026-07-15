import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';
import '../../ui/components.dart';
import 'battle_room.dart';

/// 4a 배틀 브리핑 — 5필드 비밀 구조 (당근 네고 · 보증금 · 친구 배틀 공용).
/// 공통 상황 + 당신의 상황 + 목표(승패) + 물러설 수 없는 선(+예외) + 비밀.
/// 서버가 준 자기 몫만 표시(규칙 #2). 준비완료→ready, 양측 완료→통화.
class BattleBriefScreen extends StatefulWidget {
  const BattleBriefScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleBriefScreen> createState() => _BattleBriefScreenState();
}

class _BattleBriefScreenState extends State<BattleBriefScreen> {
  BattleRoomController? _room;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _room = BattleRoomController.of(widget.roomId);
    _room?.addListener(_onRoom);
  }

  void _onRoom() {
    final room = _room!;
    if (room.inCall && !_navigated) {
      _navigated = true; // 양측 ready → 서버 in_call → 통화 화면
      if (mounted) context.go('/battle/${widget.roomId}/call');
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoom);
    super.dispose();
  }

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
              YbsButton(label: '다시 매칭하기', onTap: () => context.go('/battle/matching')),
            ],
          ),
        ),
      );
    }
    final match = room.match;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('배틀 브리핑',
                          style: TextStyle(fontFamily: YbsType.display, fontSize: 24, height: 1.2, color: YbsColor.white)),
                      Flexible(
                        child: Text(match.scenarioTitle,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.ink300)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(YbsSpace.s5, 0, YbsSpace.s5, YbsSpace.s4),
                    children: [
                      _situationCard(match),
                      const SizedBox(height: YbsSpace.s3),
                      _personalCard(match),
                      const SizedBox(height: YbsSpace.s3),
                      _goalCard(match),
                      const SizedBox(height: YbsSpace.s3),
                      _hardLineCard(match),
                      const SizedBox(height: YbsSpace.s3),
                      _secretCard(match),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, YbsSpace.s4),
                  child: Column(
                    children: [
                      YbsButton(
                        label: room.readySent ? '상대를 기다리는 중…' : '준비 완료',
                        size: YbsButtonSize.lg,
                        fullWidth: true,
                        onTap: room.readySent ? null : room.sendReady,
                      ),
                      const SizedBox(height: YbsSpace.s2 + 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: YbsColor.amber400, shape: BoxShape.circle)),
                          const SizedBox(width: YbsSpace.s2),
                          Text(room.readySent ? '상대가 준비하면 바로 시작돼요' : '준비 완료를 누르면 상대에게 알려요',
                              style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- 카드 조각 ----
  Widget _label(String text, {Color color = YbsColor.textFaint}) => Text(text,
      style: TextStyle(
          fontSize: YbsType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: YbsType.labelTracking(YbsType.micro) / 2,
          color: color));

  Widget _pill(String text, Color fg, Color border, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(YbsRadius.full)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _situationCard(BattleMatch m) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('공통 상황 · 양쪽 모두 확인'),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(m.situation, style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textBody)),
            const SizedBox(height: YbsSpace.s3),
            Row(children: [
              _pill('나 · ${m.roleLabel}', YbsColor.go300, YbsColor.go600, YbsColor.go500.withValues(alpha: 0.10)),
              const SizedBox(width: YbsSpace.s2 + 2),
              Flexible(child: _pill('상대 · ${m.opponentLabel}', YbsColor.live400, YbsColor.live600, YbsColor.live500.withValues(alpha: 0.10))),
            ]),
          ],
        ),
      );

  Widget _personalCard(BattleMatch m) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('당신의 상황'),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(m.personal, style: const TextStyle(fontSize: YbsType.sub, height: 1.6, color: YbsColor.textBody)),
          ],
        ),
      );

  Widget _goalCard(BattleMatch m) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.go600),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
          boxShadow: [BoxShadow(color: YbsColor.go500.withValues(alpha: 0.10), blurRadius: 22)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('목표', color: YbsColor.go400),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(m.goal,
                style: const TextStyle(fontFamily: YbsType.display, fontSize: 19, height: 1.3, color: YbsColor.textHero)),
            if (m.winNote.isNotEmpty) ...[
              const SizedBox(height: YbsSpace.s3),
              Container(
                padding: const EdgeInsets.only(top: YbsSpace.s3),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 15, color: YbsColor.sky400),
                    const SizedBox(width: YbsSpace.s2),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '승패  ', style: TextStyle(fontWeight: FontWeight.w700, color: YbsColor.sky400)),
                          TextSpan(text: m.winNote, style: const TextStyle(color: YbsColor.textSub)),
                        ]),
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _hardLineCard(BattleMatch m) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.live500.withValues(alpha: 0.05),
          border: Border.all(color: YbsColor.live600),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.do_not_disturb_on_outlined, size: 15, color: YbsColor.live400),
                  const SizedBox(width: 6),
                  _label('물러설 수 없는 선', color: YbsColor.live400),
                ]),
                Text('HARD LINE',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(10), color: YbsColor.live400)),
              ],
            ),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(m.hardLine,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5, color: YbsColor.textHero)),
            if (m.exceptions.isNotEmpty) ...[
              const SizedBox(height: YbsSpace.s3),
              Container(
                padding: const EdgeInsets.only(top: YbsSpace.s3),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('단, 이 선은 이렇게 움직여요', color: YbsColor.amber400),
                    const SizedBox(height: YbsSpace.s2 + 2),
                    for (final e in m.exceptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: YbsSpace.s2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.subdirectory_arrow_right, size: 14, color: YbsColor.amber400),
                            ),
                            const SizedBox(width: YbsSpace.s2),
                            Expanded(child: Text(e, style: const TextStyle(fontSize: 13, height: 1.45, color: YbsColor.textBody))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _secretCard(BattleMatch m) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: const Color(0xFF16130A),
          border: Border.all(color: YbsColor.gold500),
          borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
          boxShadow: [BoxShadow(color: YbsColor.gold400.withValues(alpha: 0.10), blurRadius: 22)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.lock_outline, size: 14, color: YbsColor.gold300),
                  const SizedBox(width: 6),
                  _label('들키면 안 되는 비밀', color: YbsColor.gold300),
                ]),
                Text('TOP SECRET',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(10), color: YbsColor.gold400)),
              ],
            ),
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(m.secret,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.6, color: Color(0xFFF5E6C0))),
            const SizedBox(height: YbsSpace.s2),
            const Text('나만 볼 수 있어요 — 상대가 눈치채면 불리해져요',
                style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
          ],
        ),
      );
}
