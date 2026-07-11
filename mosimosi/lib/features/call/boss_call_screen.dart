import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/call/call_session.dart';
import '../../core/call/llm_tasks.dart';
import '../../core/call/session_store.dart';
import '../../core/data/bosses.dart';
import '../../core/local_store.dart';
import '../../core/models/boss.dart';
import '../../platform/stt_factory.dart';
import '../../platform/tts_factory.dart';
import '../../services/game_server_client.dart';
import '../../services/llm_factory.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2.3 통화 화면 (싱글) ★막다른 방 — 통화 중 GNB 숨김, 이탈은 끊기만.
/// 스파이크 A 루프의 정식 승격판: CallSessionController(core) 배선.
/// 콘텐츠 우선순위(IA §6): ①PTT ②타이머+인내심 ③실시간 자막 ④이벤트 팝업
/// ⑤클리어 조건(접이식 칩 — 실시간 체크는 P1 인크리멘탈 심판 몫, 지금은 목록만) ⑥끊기.
class BossCallScreen extends StatefulWidget {
  const BossCallScreen({super.key, required this.bossId});

  final String bossId;

  @override
  State<BossCallScreen> createState() => _BossCallScreenState();
}

class _BossCallScreenState extends State<BossCallScreen> {
  CallSessionController? _session;
  StreamSubscription<CallEvent>? _eventSub;
  CallEvent? _popup;
  Timer? _popupTimer;
  bool _navigated = false;
  bool _conditionsOpen = false;
  final _fallbackController = TextEditingController();

  Boss? get _boss => bossById(widget.bossId);

  @override
  void initState() {
    super.initState();
    final boss = _boss;
    if (boss == null) return;
    final llm = createLlmClient();
    final session = CallSessionController(
      boss: boss,
      stt: createSttEngine(),
      tts: createTtsEngine(),
      llm: llm,
      generateVariables: () => generateScenarioVariables(llm: llm, boss: boss),
      startServerSession: (variables) async {
        final userId = LocalStore.instance.userId;
        if (userId == null) return null; // 계정 없음 — 서버 기록 스킵
        final res = await GameServerClient().postJson('/sessions', {
          'user_id': userId,
          'mode': 'boss',
          'boss_id': boss.id,
          'scenario_variables': variables,
        });
        return res['id'] as String?;
      },
    );
    _session = session;
    session.addListener(_onSession);
    _eventSub = session.events.listen(_showPopup);
    session.start();
  }

  void _onSession() {
    final s = _session!;
    if (s.phase == CallPhase.ended && !_navigated) {
      _navigated = true;
      final spoken = s.transcript.where((u) => u.text.isNotEmpty).toList();
      if (spoken.isEmpty) {
        // 연결 중 취소 등 대화 없는 종료 — 심판할 게 없으니 브리핑으로.
        if (mounted) context.go('/bosses/${s.boss.id}');
        return;
      }
      SessionStore.put(
        s.sessionId,
        CallRecord(
          boss: s.boss,
          transcript: spoken,
          endReason: s.endReason!,
          elapsedMs: s.elapsedMs,
          serverSessionId: s.serverSessionId,
        ),
      );
      if (mounted) {
        context.go('/bosses/${s.boss.id}/result/${s.sessionId}');
      }
    }
  }

  void _showPopup(CallEvent e) {
    _popupTimer?.cancel();
    setState(() => _popup = e);
    _popupTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _popup = null);
    });
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _eventSub?.cancel();
    _session?.removeListener(_onSession);
    _session?.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boss = _boss;
    final session = _session;
    if (boss == null || session == null) {
      return Scaffold(
        body: Center(
          child: Text('알 수 없는 보스: ${widget.bossId}',
              style: const TextStyle(color: YbsColor.textSub)),
        ),
      );
    }
    return PopScope(
      canPop: false, // 막다른 방 — 이탈은 끊기로만
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final phone = _phoneBody(session);
          if (isDesktop(context)) {
            return Scaffold(
              body: CallDesktopStage(
                gauge: const SizedBox.shrink(),
                leftPanels: [_conditionsPanel(session)],
                phone: phone,
                rightPanels: [_captionLogPanel(session)],
              ),
            );
          }
          return Scaffold(body: SafeArea(bottom: false, child: phone));
        },
      ),
    );
  }

  // ================================================================ phone body
  Widget _phoneBody(CallSessionController s) {
    final connectingPhase =
        s.phase == CallPhase.connecting || s.phase == CallPhase.ringing;
    return Container(
      color: YbsColor.bgIncall,
      child: Column(
        children: [
          _patienceHeader(s),
          _callerBlock(s, connecting: connectingPhase),
          Expanded(
            child: Stack(
              children: [
                if (!connectingPhase) _captionList(s),
                if (_popup != null)
                  Positioned(top: YbsSpace.s3, left: YbsSpace.s5, right: YbsSpace.s5, child: _popupCard(_popup!)),
              ],
            ),
          ),
          if (!connectingPhase) _conditionsSection(s),
          _bottomBar(s, connecting: connectingPhase),
        ],
      ),
    );
  }

  Widget _patienceHeader(CallSessionController s) {
    final silence = s.phase == CallPhase.silenceWarning;
    final barColor = silence ? YbsColor.amber400 : YbsColor.live500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('보스 인내심',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(11), color: YbsColor.live400)),
              Text('${(s.patience * 100).round()}%',
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.live400)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(YbsRadius.full),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.borderIncall),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: s.patience,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                    boxShadow: [BoxShadow(color: barColor.withValues(alpha: 0.4), blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callerBlock(CallSessionController s, {required bool connecting}) {
    final boss = s.boss;
    final timerTone = switch (s.phase) {
      CallPhase.last30s => TimerTone.critical,
      CallPhase.silenceWarning => TimerTone.warning,
      _ => TimerTone.normal,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, 0),
      child: Column(
        children: [
          YbsBadge(
            label: connecting ? 'CALLING' : 'LIVE',
            tone: connecting ? BadgeTone.neutral : BadgeTone.live,
            pulse: true,
          ),
          const SizedBox(height: YbsSpace.s2),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              border: Border.all(color: YbsColor.live600, width: 2),
              gradient: RadialGradient(
                center: const Alignment(0, -0.24),
                radius: 0.72,
                colors: [YbsColor.live500.withValues(alpha: 0.30), Colors.transparent],
              ),
              boxShadow: [BoxShadow(color: YbsColor.live500.withValues(alpha: 0.22), blurRadius: 24)],
            ),
            alignment: Alignment.center,
            child: Text(boss.portraitSyllable,
                style: const TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1, color: YbsColor.live400)),
          ),
          const SizedBox(height: YbsSpace.s2),
          Text(boss.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: YbsType.display, fontSize: 23, height: 1.2, color: YbsColor.textHero)),
          const SizedBox(height: 2),
          Text(boss.subtitle, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s2),
          if (connecting)
            Text(s.phase == CallPhase.connecting ? '연결 중…' : '신호 가는 중…',
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.bodyLg, color: YbsColor.textSub))
          else
            CallTimer(seconds: s.elapsedSeconds, tone: timerTone, label: '통화 시간'),
        ],
      ),
    );
  }

  Widget _popupCard(CallEvent e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3),
      decoration: BoxDecoration(
        color: YbsColor.amber400.withValues(alpha: 0.10),
        border: Border.all(color: YbsColor.amber400.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(YbsRadius.md),
        boxShadow: [BoxShadow(color: YbsColor.amber400.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 22, color: YbsColor.amber400),
          const SizedBox(width: YbsSpace.s3 - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, height: 1.3, color: YbsColor.amber400)),
                Text(e.subtitle, style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionList(CallSessionController s) {
    // 모바일: 직전 2~3발화 + interim (IA §6 — 데스크톱 전체 로그는 우측 패널).
    final spoken = s.transcript.where((u) => u.text.isNotEmpty).toList();
    final recent = spoken.length > 3 ? spoken.sublist(spoken.length - 3) : spoken;
    final showInterim = s.listening || s.interim.isNotEmpty;
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: YbsSpace.s3),
            LiveCaption(
              speaker: recent[i].speaker == 'boss' ? CaptionSpeaker.boss : CaptionSpeaker.player,
              name: recent[i].speaker == 'boss' ? s.boss.name : '나',
              text: recent[i].text,
              active: i == recent.length - 1 && !showInterim,
              dim: i < recent.length - 1,
            ),
          ],
          if (showInterim) ...[
            if (recent.isNotEmpty) const SizedBox(height: YbsSpace.s3),
            LiveCaption(
              speaker: CaptionSpeaker.player,
              name: '나',
              text: s.interim.isEmpty ? '…' : s.interim,
              active: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _conditionsSection(CallSessionController s) {
    if (!_conditionsOpen) {
      return Padding(
        padding: const EdgeInsets.only(bottom: YbsSpace.s3 - 2),
        child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _conditionsOpen = true),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceIncall,
                border: Border.all(color: YbsColor.borderIncall),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('달성 조건 ', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.textSub)),
                  Text('${s.boss.clearConditions.length}개',
                      style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.go400)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_up, size: 14, color: YbsColor.textSub),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(YbsSpace.s5, 0, YbsSpace.s5, YbsSpace.s2 + 2),
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3 + 2),
      decoration: BoxDecoration(
        color: YbsColor.surfaceIncall,
        border: Border.all(color: YbsColor.borderIncall),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _conditionsOpen = false),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('달성 조건 — 판정은 통화 종료 후',
                    style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('접기', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: YbsColor.textFaint),
                ]),
              ],
            ),
          ),
          const SizedBox(height: YbsSpace.s2 + 2),
          for (final c in s.boss.clearConditions)
            Padding(
              padding: const EdgeInsets.only(bottom: YbsSpace.s2),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: YbsColor.ink500, width: 2)),
                  ),
                  const SizedBox(width: YbsSpace.s3 - 2),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(CallSessionController s, {required bool connecting}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, YbsSpace.s6 + 2),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        border: Border(top: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallIconButton(
                icon: Icons.call_end,
                label: connecting ? '취소' : '종료',
                kind: CallButtonKind.endCall,
                onTap: s.hangUp,
              ),
              if (!connecting) ...[
                const SizedBox(width: YbsSpace.s3),
                Expanded(child: s.sttAvailable ? _pttButton(s) : _textFallback(s)),
              ],
            ],
          ),
          if (!connecting && s.sttAvailable) ...[
            const SizedBox(height: YbsSpace.s2 + 2),
            const Text('손을 떼면 음성이 전송돼요', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
          ],
        ],
      ),
    );
  }

  Widget _pttButton(CallSessionController s) {
    final silence = s.phase == CallPhase.silenceWarning;
    final label = s.busy
        ? '상대가 말하는 중…'
        : s.listening
            ? '듣는 중 — 떼면 전송'
            : silence
                ? '지금 말할 차례예요'
                : '누르는 동안 말하기';
    return GestureDetector(
      onTapDown: (_) => s.pressTalk(),
      onTapUp: (_) => s.releaseTalk(),
      onTapCancel: s.releaseTalk,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: s.busy ? YbsColor.ink700 : YbsColor.go500,
          borderRadius: BorderRadius.circular(YbsRadius.lg),
          border: Border.all(color: s.busy ? YbsColor.borderStrong : YbsColor.go600),
          boxShadow: s.busy ? null : [BoxShadow(color: YbsColor.goGlow, blurRadius: 24)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: 24, color: s.busy ? YbsColor.textSub : YbsColor.textOnGo),
            const SizedBox(width: YbsSpace.s2 + 2),
            Text(label,
                style: TextStyle(
                    fontFamily: YbsType.body,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: s.busy ? YbsColor.textSub : YbsColor.textOnGo)),
          ],
        ),
      ),
    );
  }

  Widget _textFallback(CallSessionController s) {
    // STT 불가 → 텍스트 입력 폴백 (UI 규칙).
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _fallbackController,
              style: const TextStyle(color: YbsColor.textBody),
              decoration: const InputDecoration(
                hintText: '음성 인식 불가 — 텍스트로 말하기',
                hintStyle: TextStyle(color: YbsColor.textFaint),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendFallback(s),
            ),
          ),
          IconButton(
            onPressed: () => _sendFallback(s),
            icon: const Icon(Icons.send, color: YbsColor.go400),
          ),
        ],
      ),
    );
  }

  void _sendFallback(CallSessionController s) {
    final text = _fallbackController.text.trim();
    if (text.isEmpty) return;
    _fallbackController.clear();
    s.sendText(text);
  }

  // ================================================================ desktop panels
  Widget _conditionsPanel(CallSessionController s) {
    return HudPanel(
      title: '달성 조건',
      label: 'GOAL',
      tone: HudTone.go,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in s.boss.clearConditions)
            Padding(
              padding: const EdgeInsets.only(bottom: YbsSpace.s3),
              child: Text('· $c', style: const TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody, color: YbsColor.textBody)),
            ),
        ],
      ),
    );
  }

  Widget _captionLogPanel(CallSessionController s) {
    final spoken = s.transcript.where((u) => u.text.isNotEmpty).toList();
    return HudPanel(
      title: '캡션 로그',
      label: 'REC',
      live: true,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in spoken)
            Padding(
              padding: const EdgeInsets.only(bottom: YbsSpace.s3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${u.speaker == 'boss' ? s.boss.name : '나'} ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: u.speaker == 'boss' ? YbsColor.live400 : YbsColor.go400)),
                  TextSpan(text: '— ${u.text}', style: const TextStyle(color: YbsColor.textSub)),
                ]),
                style: const TextStyle(fontSize: YbsType.sub, height: YbsType.leadingBody),
              ),
            ),
        ],
      ),
    );
  }
}
