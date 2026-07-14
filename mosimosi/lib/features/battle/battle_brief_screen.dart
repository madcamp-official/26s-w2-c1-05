import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';
import '../../ui/components.dart';
import 'battle_room.dart';

/// 3.2 배틀 브리핑 (비공개) — 디자인 H 섹션 이식.
/// 공통 상황 + 비밀 구분선 + 비밀 목표(SECRET) + 규칙 카드(RULE·상담원만).
/// 실배선: 서버가 준 자기 몫만 표시(규칙 #2), 준비완료→ready, 양측 완료→통화.
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
      // 딥링크/재시작 등으로 방 컨텍스트 소실 — 재매칭 안내.
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: YbsSpace.s5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('배틀 브리핑',
                          style: TextStyle(fontFamily: YbsType.display, fontSize: 22, height: 1.2, color: YbsColor.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: YbsColor.amber400.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(YbsRadius.full),
                        ),
                        child: Text('양쪽 준비되면 시작',
                            style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.amber400)),
                      ),
                    ],
                  ),
                  const SizedBox(height: YbsSpace.s4),
                  // 공통 상황
                  Container(
                    padding: const EdgeInsets.all(YbsSpace.s4),
                    decoration: BoxDecoration(
                      color: YbsColor.surfaceCard,
                      border: Border.all(color: YbsColor.borderSoft),
                      borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('공통 상황 · 양쪽 모두 확인',
                            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.textFaint)),
                        const SizedBox(height: YbsSpace.s2 + 2),
                        Text(match.situation,
                            style: const TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
                        const SizedBox(height: YbsSpace.s2 + 2),
                        Row(children: [
                          _rolePill('나 · ${match.roleLabel}', YbsColor.go300, YbsColor.go600, YbsColor.go500.withValues(alpha: 0.10)),
                          const SizedBox(width: YbsSpace.s2 + 2),
                          Flexible(
                            child: _rolePill('${match.opponentNickname} · ${match.opponentRoleLabel}',
                                YbsColor.live400, YbsColor.live600, YbsColor.live500.withValues(alpha: 0.10)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // 비밀 구분선
                  Row(children: [
                    const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s2 + 2),
                      child: Row(children: [
                        const Icon(Icons.lock_outline, size: 14, color: YbsColor.gold300),
                        const SizedBox(width: 6),
                        Text('여기부터는 비밀 — 상대에게 보이지 않아요',
                            style: TextStyle(
                                fontSize: YbsType.micro,
                                fontWeight: FontWeight.w700,
                                letterSpacing: YbsType.labelTracking(YbsType.micro),
                                color: YbsColor.gold300)),
                      ]),
                    ),
                    const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
                  ]),
                  const SizedBox(height: YbsSpace.s4 - 2),
                  _secretCard(
                    header: '비밀 목표',
                    tag: 'SECRET',
                    accent: YbsColor.go400,
                    border: YbsColor.go600,
                    bg: YbsColor.go500.withValues(alpha: 0.06),
                    glow: YbsColor.go500.withValues(alpha: 0.10),
                    body: Text(match.secretGoal,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
                    note: '달성 시 판정에 크게 반영돼요',
                  ),
                  if (match.ruleCard != null) ...[
                    const SizedBox(height: YbsSpace.s4 - 2),
                    _secretCard(
                      header: '규칙 카드 · ${match.roleLabel} 전용',
                      tag: 'RULE',
                      accent: YbsColor.live400,
                      border: YbsColor.borderIncall,
                      bg: YbsColor.live500.withValues(alpha: 0.05),
                      glow: null,
                      body: Text(match.ruleCard!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
                      note: '규칙 위반은 판정에서 불리하게 반영돼요',
                    ),
                  ],
                  const Spacer(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: YbsButton(
                        label: room.readySent ? '상대를 기다리는 중…' : '준비 완료',
                        size: YbsButtonSize.lg,
                        fullWidth: true,
                        onTap: room.readySent ? null : room.sendReady,
                      ),
                    ),
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolePill(String label, Color fg, Color border, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(YbsRadius.full)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _secretCard({
    required String header,
    required String tag,
    required Color accent,
    required Color border,
    required Color bg,
    required Color? glow,
    required Widget body,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
        boxShadow: glow == null ? null : [BoxShadow(color: glow, blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(header,
                  style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: accent)),
              Text(tag,
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(10), color: accent)),
            ],
          ),
          const SizedBox(height: YbsSpace.s2),
          body,
          const SizedBox(height: YbsSpace.s2),
          Text(note, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
        ],
      ),
    );
  }
}
