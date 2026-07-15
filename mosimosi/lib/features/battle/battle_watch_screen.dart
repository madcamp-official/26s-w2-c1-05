import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'battle_watch_controller.dart';

/// 5. 관전 화면 (데모 프로젝터, 데스크톱 전용) — 진행 중 배틀을 읽기 전용으로 중계.
/// 상단: LIVE·SPECTATOR + 양측 프로필 + 기세 바 + 타이머. 본문: 양측 폰 2열.
/// 캐스터·판정 기준 패널 없음. 비밀 목표/규칙 카드는 서버가 원천 미전송(규칙 #2).
class BattleWatchScreen extends StatefulWidget {
  const BattleWatchScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleWatchScreen> createState() => _BattleWatchScreenState();
}

class _BattleWatchScreenState extends State<BattleWatchScreen> {
  late final BattleWatchController _watch =
      BattleWatchController(roomId: widget.roomId)..addListener(_onUpdate);

  @override
  void initState() {
    super.initState();
    _watch.connect();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _watch.removeListener(_onUpdate);
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YbsColor.bgIncall,
      body: SafeArea(
        child: Column(
          children: [
            _topStrip(),
            Expanded(
              child: _watch.state == 'disconnected'
                  ? _disconnected()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: YbsSpace.s8, vertical: YbsSpace.s6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _phone(isAgent: false)),
                          const SizedBox(width: YbsSpace.s8),
                          Expanded(child: _phone(isAgent: true)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disconnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('관전 연결이 끊겼어요',
              style: TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s4),
          YbsButton(
              label: '설정으로',
              variant: YbsButtonVariant.ghost,
              onTap: () => context.go('/settings')),
        ],
      ),
    );
  }

  // ---- 상단 스트립 (양측 프로필 + 기세 바 + 타이머) ----
  Widget _topStrip() {
    final agentMom = _watch.momentumAgent;
    return Container(
      height: YbsLayout.stageTopH,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s8),
      decoration: const BoxDecoration(
        color: YbsColor.surfaceIncall,
        border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Row(
        children: [
          const YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
          const SizedBox(width: YbsSpace.s2 + 2),
          const YbsBadge(label: 'SPECTATOR', tone: BadgeTone.neutral, mono: true),
          const SizedBox(width: YbsSpace.s6),
          _profile(agent: false, alignRight: false),
          const SizedBox(width: YbsSpace.s6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(YbsRadius.full),
                  child: Container(
                    height: 14,
                    color: YbsColor.live500, // claimant 쪽(우측) 바탕
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (agentMom / 100).clamp(0.05, 0.95),
                      child: Container(
                        decoration: BoxDecoration(
                          color: YbsColor.go500,
                          boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$agentMom : ${100 - agentMom}',
                    style: const TextStyle(
                        fontFamily: YbsType.numeric,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: YbsColor.textSub)),
              ],
            ),
          ),
          const SizedBox(width: YbsSpace.s6),
          _profile(agent: true, alignRight: true),
          const SizedBox(width: YbsSpace.s6),
          CallTimer(seconds: _watch.elapsedSeconds, label: '라운드 1 · 05:00'),
        ],
      ),
    );
  }

  Widget _profile({required bool agent, required bool alignRight}) {
    final accent = agent ? YbsColor.go400 : YbsColor.live400;
    final border = agent ? YbsColor.go600 : YbsColor.live600;
    final nick = agent ? _watch.agentNick : _watch.claimantNick;
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: YbsColor.surfaceInset,
        gradient: RadialGradient(
          center: const Alignment(0, -0.24),
          radius: 0.72,
          colors: [accent.withValues(alpha: 0.25), Colors.transparent],
        ),
        border: Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(nick.characters.first,
          style: TextStyle(fontFamily: YbsType.display, fontSize: 15, height: 1, color: accent)),
    );
    final texts = Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nick,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, height: 1.2, color: accent)),
        Text(agent ? '상담원' : '민원인', style: const TextStyle(fontSize: 11, color: YbsColor.textSub)),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: alignRight
          ? [texts, const SizedBox(width: YbsSpace.s2 + 2), avatar]
          : [avatar, const SizedBox(width: YbsSpace.s2 + 2), texts],
    );
  }

  /// 감독 시점 — 해당 플레이어의 비밀 목표(+상담원 규칙 카드)를 관전자에게 노출.
  Widget _secretBox({required bool isAgent}) {
    final secret = isAgent ? _watch.agentSecret : _watch.claimantSecret;
    final ruleCard = isAgent ? _watch.agentRuleCard : null;
    if (secret.isEmpty) return const SizedBox.shrink();
    final accent = isAgent ? YbsColor.go400 : YbsColor.live400;
    final border = isAgent ? YbsColor.go600 : YbsColor.live600;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(YbsSpace.s4, YbsSpace.s3, YbsSpace.s4, 0),
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s3 + 2, vertical: YbsSpace.s3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(YbsRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lock_open_outlined, size: 13, color: accent),
            const SizedBox(width: 6),
            Text('비밀 목표',
                style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: accent)),
          ]),
          const SizedBox(height: 4),
          Text(secret,
              style: const TextStyle(fontSize: YbsType.micro, height: 1.45, color: YbsColor.textBody)),
          if (ruleCard != null && ruleCard.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('규칙 · $ruleCard',
                style: const TextStyle(fontSize: 10, height: 1.4, color: YbsColor.textSub)),
          ],
        ],
      ),
    );
  }

  // ---- 양측 폰 (실 발화 스트림) ----
  Widget _phone({required bool isAgent}) {
    final glow = isAgent ? YbsColor.go500 : YbsColor.live500;
    final lines = isAgent ? _watch.agentLine : _watch.claimantLine;
    final nick = isAgent ? _watch.agentNick : _watch.claimantNick;
    final recent = lines.length > 6 ? lines.sublist(lines.length - 6) : lines;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3440), Color(0xFF12151C), Color(0xFF232936)],
          ),
          border: Border.all(color: const Color(0xFF3C4454)),
          borderRadius: BorderRadius.circular(48),
          boxShadow: [...YbsShadow.pop, BoxShadow(color: glow.withValues(alpha: 0.10), blurRadius: 40)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: Container(
            color: YbsColor.bgIncall,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(
                    color: YbsColor.surfaceInset,
                    border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: nick,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                      TextSpan(text: ' · ${isAgent ? '상담원' : '민원인'} 화면'),
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub),
                  ),
                ),
                _secretBox(isAgent: isAgent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(YbsSpace.s4),
                    child: recent.isEmpty
                        ? const Center(
                            child: Text('발화 대기 중…',
                                style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < recent.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(top: YbsSpace.s3),
                                  child: LiveCaption(
                                    speaker: isAgent ? CaptionSpeaker.player : CaptionSpeaker.boss,
                                    name: nick,
                                    text: recent[i].text,
                                    active: i == recent.length - 1,
                                    dim: i < recent.length - 1,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: YbsSpace.s4 - 2),
                  decoration: const BoxDecoration(
                    color: Color(0x59000000),
                    border: Border(top: BorderSide(color: YbsColor.borderIncall)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: YbsColor.live500, shape: BoxShape.circle)),
                      const SizedBox(width: YbsSpace.s2),
                      Text('SPECTATOR · 실시간 관전',
                          style: TextStyle(
                              fontFamily: YbsType.numeric,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: YbsType.labelTracking(11),
                              color: YbsColor.textFaint)),
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
}
