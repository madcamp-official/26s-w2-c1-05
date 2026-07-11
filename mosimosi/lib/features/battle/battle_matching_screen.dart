import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/local_store.dart';
import '../../platform/tts_factory.dart';
import '../../services/game_server_client.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'battle_room.dart';

/// 3.1 배틀 매칭 — 디자인 G 섹션 이식.
/// 탐색 중(경과 타이머) → 매칭 완료(VS·역할 배정) → 30초 폴백(AI 배틀 시트).
/// 실배선: /ws/match 큐 진입, matched 이벤트로 방 컨트롤러 생성(Phase 3).
/// 30초 폴백은 클라 타이머(서버는 큐 이탈만) — AI 배틀 자체는 서버 미구현.
class BattleMatchingScreen extends StatefulWidget {
  const BattleMatchingScreen({super.key});

  @override
  State<BattleMatchingScreen> createState() => _BattleMatchingScreenState();
}

enum _State { searching, matched, fallback }

class _BattleMatchingScreenState extends State<BattleMatchingScreen> {
  _State _state = _State.searching;
  int _elapsed = 0;
  Timer? _timer;
  WebSocketChannel? _matchSocket;
  BattleMatch? _match; // matched 이벤트 수신분 (내 몫 브리핑)
  String? _error;

  String get _myNickname => LocalStore.instance.nickname ?? '나';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_state == _State.searching && _elapsed >= 30) _state = _State.fallback;
      });
    });
    _enterQueue();
  }

  void _enterQueue() {
    final userId = LocalStore.instance.userId;
    if (userId == null) {
      setState(() => _error = '계정이 없어요 — 온보딩을 먼저 진행해 주세요.');
      return;
    }
    final socket = GameServerClient().connectMatchSocket(
      userId: userId,
      nickname: _myNickname,
      formFactor:
          defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows',
    );
    _matchSocket = socket;
    socket.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] != 'matched' || !mounted) return;
        final match = BattleMatch.fromJson(msg);
        // 방 컨트롤러 생성 + 방 소켓 즉시 연결 (ready는 브리핑에서 전송).
        final controller = BattleRoomController(
          match: match,
          myUserId: userId,
          tts: createTtsEngine(),
        );
        BattleRoomController.register(controller);
        controller.connect();
        socket.sink.close(); // 매칭 소켓 역할 종료 — 이후는 /ws/room
        setState(() {
          _match = match;
          _state = _State.matched;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _error = '매칭 서버에 연결할 수 없어요.');
      },
      onDone: () {
        // 매칭 전 서버가 끊은 경우만 오류 (성사 후 close는 정상 흐름).
        if (mounted && _state == _State.searching && _error == null) {
          setState(() => _error = '매칭 서버와 연결이 끊겼어요.');
        }
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _matchSocket?.sink.close(); // 큐 이탈 (서버가 disconnect로 제거)
    super.dispose();
  }

  String get _mmss =>
      '${(_elapsed ~/ 60).toString().padLeft(2, '0')}:${(_elapsed % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _error != null
            ? _errorBody()
            : switch (_state) {
                _State.searching => _searching(),
                _State.matched => _matched(),
                _State.fallback => _fallback(),
              },
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
          const SizedBox(height: YbsSpace.s5),
          YbsButton(label: '홈으로', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
        ],
      ),
    );
  }

  // ---- 탐색 중 ----
  Widget _searching({bool dimmed = false}) {
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.72,
                colors: [YbsColor.go500.withValues(alpha: 0.16), Colors.transparent],
              ),
              border: Border.all(color: YbsColor.go600, width: 2),
              boxShadow: dimmed ? null : [BoxShadow(color: YbsColor.goGlow, blurRadius: 32)],
            ),
            child: const Icon(Icons.call, size: 42, color: YbsColor.go400),
          ),
          const SizedBox(height: YbsSpace.s5),
          const Text('상대를 찾는 중…',
              style: TextStyle(fontFamily: YbsType.display, fontSize: 28, height: 1.2, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          Text(_mmss,
              style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 32, fontWeight: FontWeight.w600, height: 1.1, color: YbsColor.go400)),
          if (!dimmed) ...[
            const SizedBox(height: YbsSpace.s2),
            const Text('상대가 매칭을 누르면 바로 연결돼요.\n같은 서버의 다른 기기에서 접속해 보세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textSub)),
            const SizedBox(height: YbsSpace.s5),
            YbsButton(label: '취소', variant: YbsButtonVariant.ghost, onTap: () => context.go('/home')),
          ],
        ],
      ),
    );
    return dimmed
        ? Opacity(opacity: 0.28, child: IgnorePointer(child: body))
        : body;
  }

  // ---- 매칭 완료 ----
  Widget _matched() {
    final match = _match!;
    Widget player({
      required String name,
      required String role,
      required bool isMe,
    }) {
      final accent = isMe ? YbsColor.go400 : YbsColor.live400;
      final border = isMe ? YbsColor.go600 : YbsColor.live600;
      final glow = isMe ? YbsColor.goGlow : YbsColor.liveGlow;
      return SizedBox(
        width: 120,
        child: Column(children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              gradient: RadialGradient(
                center: const Alignment(0, -0.24),
                radius: 0.72,
                colors: [accent.withValues(alpha: 0.25), Colors.transparent],
              ),
              border: Border.all(color: border, width: 2),
              boxShadow: [BoxShadow(color: glow, blurRadius: 26)],
            ),
            alignment: Alignment.center,
            child: Text(name.characters.first,
                style: TextStyle(fontFamily: YbsType.display, fontSize: 34, height: 1, color: accent)),
          ),
          const SizedBox(height: YbsSpace.s2 + 2),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2 + 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: Text(role, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: accent)),
          ),
        ]),
      );
    }

    final oppOnWindows = match.opponentFormFactor == 'windows';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('상대를 찾았어요!',
                style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1.2, color: YbsColor.textHero)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                player(name: _myNickname, role: match.roleLabel, isMe: true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: YbsSpace.s4 + 2),
                  child: Text('VS',
                      style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1, color: YbsColor.live500)),
                ),
                player(name: match.opponentNickname, role: match.opponentRoleLabel, isMe: false),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: 7),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(oppOnWindows ? Icons.desktop_windows_outlined : Icons.smartphone,
                      size: 14, color: YbsColor.sky400),
                  const SizedBox(width: YbsSpace.s2),
                  Text('상대는 ${oppOnWindows ? 'Windows' : 'Android'}에서 접속 중',
                      style: const TextStyle(fontSize: 13, color: YbsColor.textSub)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: YbsButton(
                label: '브리핑 확인하기',
                size: YbsButtonSize.lg,
                fullWidth: true,
                onTap: () => context.go('/battle/${match.roomId}/brief'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 30초 폴백 시트 ----
  Widget _fallback() {
    return Stack(
      children: [
        _searching(dimmed: true),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s6, YbsSpace.s5, 30),
            decoration: const BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border(top: BorderSide(color: YbsColor.borderStrong)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(YbsRadius.xl)),
              boxShadow: YbsShadow.pop,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: YbsColor.ink500, borderRadius: BorderRadius.circular(YbsRadius.full)),
                  ),
                ),
                const SizedBox(height: YbsSpace.s4 - 2),
                const Text('상대가 없어요',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.2, color: YbsColor.textHero)),
                const SizedBox(height: YbsSpace.s3),
                const Text('30초 동안 상대를 찾지 못했어요.\n계속 기다리면 큐는 유지돼요 — 상대가 들어오는 즉시 연결됩니다.',
                    style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textSub)),
                const SizedBox(height: YbsSpace.s4 + 2),
                YbsButton(
                  label: 'AI와 배틀하기 (준비 중)',
                  size: YbsButtonSize.lg,
                  fullWidth: true,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI 상담원 배틀은 준비 중이에요 — 조금만 기다려 주세요.')),
                  ),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                YbsButton(
                  label: '계속 기다리기',
                  variant: YbsButtonVariant.secondary,
                  fullWidth: true,
                  onTap: () => setState(() {
                    _state = _State.searching; // 큐는 유지 중 — 표시만 복귀
                    _elapsed = 0;
                  }),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                YbsButton(
                  label: '나가기',
                  variant: YbsButtonVariant.ghost,
                  size: YbsButtonSize.sm,
                  fullWidth: true,
                  onTap: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
