import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../platform/stt_engine.dart';
import '../../platform/stt_factory.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../battle/battle_room.dart';
import 'call_desktop.dart';

/// 3.3 배틀 통화 화면 ★막다른 방 — B-lite 텍스트 릴레이(Phase 3 실배선).
/// 오픈마이크: 통화 시작 시 STT를 1회 start()하고 계속 스트리밍 — 서버(whisper)
/// VAD가 0.8초 침묵마다 알아서 발화를 끊어 isFinal 결과를 순차로 내려주므로
/// PTT 버튼 없이도 매 결과를 그대로 /ws/room utterance로 전송한다.
/// 상대 발화 수신 시 TtsEngine 재생. STT 불가 시 텍스트 폴백.
/// 기세 게이지는 인크리멘탈 심판(P1) 전까지 중립 고정, 관전 시점은 watch 화면 몫.
class BattleCallScreen extends StatefulWidget {
  const BattleCallScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleCallScreen> createState() => _BattleCallScreenState();
}

class _BattleCallScreenState extends State<BattleCallScreen> {
  BattleRoomController? _room;
  SttEngine? _stt;
  StreamSubscription<SttResult>? _sttSub;
  Timer? _clock; // 통화 시간 표시용 1초 틱

  bool _sttAvailable = false;
  bool _micStarted = false; // 오픈마이크 1회성 시작 가드
  bool _micActive = false;
  String _interim = '';
  bool _secretOpen = false;
  bool _navigated = false;
  bool _silenceTimerStarted = false; // 침묵 타이머 1회성 시작 가드
  Timer? _silenceTimer;
  bool _showOpeningPopup = false;
  final _fallbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final room = BattleRoomController.of(widget.roomId);
    _room = room;
    if (room == null) return;
    room.addListener(_onRoom);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && room.inCall) setState(() {});
    });
    final stt = createSttEngine();
    _stt = stt;
    _sttSub = stt.results.listen(_onSttResult);
    stt.initialize().then((ok) {
      if (!mounted) return;
      setState(() => _sttAvailable = ok);
      _maybeStartMic();
    });
  }

  /// 오픈마이크: STT 준비 + 통화 시작, 두 조건이 모두 갖춰지면 1회만 start().
  void _maybeStartMic() {
    final room = _room;
    if (room == null || !room.inCall || !_sttAvailable || _micStarted) {
      debugPrint('[BattleCall] _maybeStartMic 보류 — '
          'room=${room != null} inCall=${room?.inCall} '
          'sttAvailable=$_sttAvailable micStarted=$_micStarted');
      return;
    }
    debugPrint('[BattleCall] _maybeStartMic → 실제 start() 호출');
    _micStarted = true;
    _micActive = true;
    _stt!.start();
  }

  void _onRoom() {
    final room = _room!;
    _maybeStartMic();
    if (room.inCall && !_silenceTimerStarted) {
      _silenceTimerStarted = true; // 통화 시작 시 1회만 시작
      _silenceTimer = Timer(const Duration(seconds: 6), () {
        // 6초 지나도 양쪽 다 아무 말 없으면 제안 첫마디 노출.
        if (mounted && room.utterances.isEmpty) {
          setState(() => _showOpeningPopup = true);
        }
      });
    }
    if (_showOpeningPopup && room.utterances.isNotEmpty) {
      _showOpeningPopup = false; // 누구든 말을 시작하면 즉시 닫기
    }
    if (room.ended && !_navigated) {
      _navigated = true; // judging 진입 즉시 결과 화면 (스피너 → verdict)
      if (mounted) context.go('/battle/${widget.roomId}/result');
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock?.cancel();
    _silenceTimer?.cancel();
    _sttSub?.cancel();
    _stt?.stop();
    _room?.removeListener(_onRoom);
    _fallbackController.dispose();
    super.dispose();
  }

  // ============================================================ 오픈마이크
  /// 서버(whisper) VAD가 침묵마다 끊어주는 isFinal 결과를 그대로 전송 —
  /// 클라 쪽에 별도 침묵판정·버튼 상호작용이 필요 없다.
  void _onSttResult(SttResult r) {
    if (!mounted) return;
    if (r.isFinal) {
      setState(() => _interim = '');
      _room?.sendUtterance(r.text, tStartMs: r.tStartMs);
    } else {
      setState(() => _interim = r.text);
    }
  }

  void _sendFallback() {
    final room = _room;
    final text = _fallbackController.text.trim();
    if (text.isEmpty || room == null || !room.inCall) return;
    _fallbackController.clear();
    room.sendUtterance(text, tStartMs: room.elapsedMs);
  }

  // ================================================================ build
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
              YbsButton(label: '다시 매칭하기', onTap: () => context.go('/battle')),
            ],
          ),
        ),
      );
    }
    final phone = _phoneBody(room);
    return PopScope(
      canPop: false, // 막다른 방 — 이탈은 종료 버튼으로만
      child: isDesktop(context)
          ? Scaffold(
              body: buildCallDesktopStage(
                phone: phone,
                rightLabel: room.match.opponentNickname,
                momentum: 0.5, // 실시간 기세는 인크리멘탈 심판(P1) 몫 — 중립 고정
                mission: room.match.secretGoal,
              ),
            )
          : Scaffold(body: SafeArea(bottom: false, child: phone)),
    );
  }

  Widget _phoneBody(BattleRoomController room) {
    return Container(
      color: YbsColor.bgIncall,
      child: Column(
        children: [
          _momentumHeader(room),
          _callerBlock(room),
          _secretChip(room),
          if (_showOpeningPopup) _openingSuggestion(room),
          Expanded(child: _captionList(room)),
          _micStatus(room),
          if (room.state == 'disconnected') _disconnectedBar() else _playerControls(room),
        ],
      ),
    );
  }

  Widget _momentumHeader(BattleRoomController room) {
    final match = room.match;
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('나 · ${match.roleLabel}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go400)),
              ),
              const SizedBox(width: YbsSpace.s2),
              Text('판정은 통화 종료 후',
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(11), color: YbsColor.textFaint)),
              const SizedBox(width: YbsSpace.s2),
              Expanded(
                child: Text('${match.opponentNickname} · ${match.opponentRoleLabel}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.live400)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _tugBar(),
        ],
      ),
    );
  }

  /// 실시간 기세 미지원(P1) — 중립 50:50 표시.
  Widget _tugBar() {
    return SizedBox(
      height: 12,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: YbsColor.live600, borderRadius: BorderRadius.circular(YbsRadius.full)),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: YbsColor.go500,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(YbsRadius.full)),
                  boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(width: 3, height: 12, decoration: BoxDecoration(color: YbsColor.white, borderRadius: BorderRadius.circular(2))),
          ),
        ],
      ),
    );
  }

  Widget _callerBlock(BattleRoomController room) {
    final limit = 300; // 서버 time_limit_s와 동일 (초과 시 서버가 judging 전환)
    final remaining = (limit - room.elapsedSeconds).clamp(0, limit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
              SizedBox(width: YbsSpace.s2),
              YbsBadge(label: '전화 배틀', tone: BadgeTone.neutral),
            ],
          ),
          const SizedBox(height: YbsSpace.s2),
          CallTimer(
            seconds: room.elapsedSeconds,
            tone: remaining <= 30 ? TimerTone.critical : TimerTone.normal,
            label: '통화 시간 · 제한 05:00',
          ),
        ],
      ),
    );
  }

  /// 비밀 목표 접이식 칩 — 내 몫만 (규칙 #2). 펼치면 목표(+규칙 카드) 표시.
  Widget _secretChip(BattleRoomController room) {
    final match = room.match;
    if (!_secretOpen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 0),
        child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _secretOpen = true),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4 - 2),
              decoration: BoxDecoration(
                color: YbsColor.go500.withValues(alpha: 0.08),
                border: Border.all(color: YbsColor.go600),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, size: 14, color: YbsColor.go300),
                  SizedBox(width: 7),
                  Text('비밀 목표', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go300)),
                  SizedBox(width: 7),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: YbsColor.go300),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 0),
      child: GestureDetector(
        onTap: () => setState(() => _secretOpen = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3),
          decoration: BoxDecoration(
            color: YbsColor.go500.withValues(alpha: 0.06),
            border: Border.all(color: YbsColor.go600),
            borderRadius: BorderRadius.circular(YbsRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('비밀 목표 — 나만 보여요',
                      style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go300)),
                  Icon(Icons.keyboard_arrow_up, size: 14, color: YbsColor.go300),
                ],
              ),
              const SizedBox(height: 6),
              Text(match.secretGoal,
                  style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textHero)),
              if (match.ruleCard != null) ...[
                const SizedBox(height: YbsSpace.s2),
                Text('규칙 · ${match.ruleCard!}',
                    style: const TextStyle(fontSize: YbsType.micro, height: 1.5, color: YbsColor.textSub)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 6초 침묵 후에도 발화가 없으면 노출 — 누군가 말을 시작하면 즉시 닫힘.
  Widget _openingSuggestion(BattleRoomController room) {
    final line = room.match.openingLine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: YbsColor.amber400.withValues(alpha: 0.10),
          border: Border.all(color: YbsColor.amber400.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('첫마디를 시작해보세요!',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.amber400)),
            if (line.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('"$line"',
                  style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textBody)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _captionList(BattleRoomController room) {
    final caps = room.utterances;
    final showInterim = _interim.isNotEmpty;
    // 전사 로그는 하단 고정 + 넘치면 스크롤(reverse).
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < caps.length; i++) ...[
            if (i > 0) const SizedBox(height: YbsSpace.s3),
            LiveCaption(
              speaker: caps[i].fromUserId == room.myUserId ? CaptionSpeaker.player : CaptionSpeaker.boss,
              name: caps[i].fromUserId == room.myUserId ? '나' : room.match.opponentNickname,
              text: caps[i].text,
              active: i == caps.length - 1 && !showInterim,
              dim: i < caps.length - 1,
            ),
          ],
          if (showInterim) ...[
            if (caps.isNotEmpty) const SizedBox(height: YbsSpace.s3),
            LiveCaption(
              speaker: CaptionSpeaker.player,
              name: '나',
              text: _interim.isEmpty ? '…' : _interim,
              active: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _micStatus(BattleRoomController room) {
    final label = !room.inCall
        ? '연결 중…'
        : _sttAvailable
            ? '듣고 있어요 — 편하게 말하세요'
            : '텍스트로 말하기 (STT 불가)';
    return Padding(
      padding: const EdgeInsets.only(bottom: YbsSpace.s3),
      child: Center(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5 - 2),
          decoration: BoxDecoration(
            color: YbsColor.go500.withValues(alpha: 0.08),
            border: Border.all(color: YbsColor.go600),
            borderRadius: BorderRadius.circular(YbsRadius.full),
            boxShadow: [BoxShadow(color: YbsColor.go500.withValues(alpha: 0.12), blurRadius: 18)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                    child: Container(
                        width: 3,
                        height: _micActive ? 16 : 8,
                        decoration: BoxDecoration(color: YbsColor.go400, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ),
              const SizedBox(width: YbsSpace.s3 - 2),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: YbsColor.go300)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerControls(BattleRoomController room) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3 - 2, YbsSpace.s5, YbsSpace.s6 + 2),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        border: Border(top: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CallIconButton(
            icon: Icons.call_end,
            label: '종료',
            kind: CallButtonKind.endCall,
            onTap: room.hangUp,
          ),
          // 오픈마이크: STT 가능하면 버튼 없이 상시 청취(_micStatus 배지가 상태 표시).
          // STT 불가할 때만 텍스트 입력으로 대체.
          if (!_sttAvailable) ...[
            const SizedBox(width: YbsSpace.s3),
            Expanded(child: _textFallback(room)),
          ],
        ],
      ),
    );
  }

  Widget _textFallback(BattleRoomController room) {
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
              onSubmitted: (_) => _sendFallback(),
            ),
          ),
          IconButton(
            onPressed: _sendFallback,
            icon: const Icon(Icons.send, color: YbsColor.go400),
          ),
        ],
      ),
    );
  }

  Widget _disconnectedBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s6),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        border: Border(top: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Column(
        children: [
          const Text('서버와 연결이 끊겼어요',
              style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.live400)),
          const SizedBox(height: YbsSpace.s3),
          YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
        ],
      ),
    );
  }
}
