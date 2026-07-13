import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../platform/pcm_player.dart';
import '../../services/game_server_client.dart';

/// 매칭 성사 페이로드 — 서버 /ws/match `matched` 이벤트의 자기 몫(규칙 #2).
class BattleMatch {
  const BattleMatch({
    required this.roomId,
    required this.role,
    required this.secretGoal,
    required this.ruleCard,
    required this.situation,
    required this.openingLine,
    required this.opponentNickname,
    required this.opponentFormFactor,
  });

  final String roomId;
  final String role; // 'agent' | 'claimant'
  final String secretGoal;
  final String? ruleCard; // 상담원 전용 — 민원인은 null
  final String situation;
  final String openingLine; // 침묵 지속 시 제안할 내 몫의 첫마디
  final String opponentNickname;
  final String opponentFormFactor; // 'android' | 'windows'

  bool get isAgent => role == 'agent';
  String get roleLabel => isAgent ? '상담원' : '민원인';
  String get opponentRoleLabel => isAgent ? '민원인' : '상담원';

  factory BattleMatch.fromJson(Map<String, dynamic> j) => BattleMatch(
        roomId: j['roomId'] as String,
        role: j['role'] as String,
        secretGoal: j['secretGoal'] as String? ?? '',
        ruleCard: j['ruleCard'] as String?,
        situation: j['situation'] as String? ?? '',
        openingLine: j['openingLine'] as String? ?? '',
        opponentNickname:
            (j['opponent'] as Map<String, dynamic>?)?['nickname'] as String? ?? '상대',
        opponentFormFactor:
            (j['opponent'] as Map<String, dynamic>?)?['formFactor'] as String? ?? 'android',
      );
}

/// 배틀 발화 한 건 (서버 브로드캐스트가 단일 진실 — 양측 순서 일치 보장).
class BattleUtterance {
  const BattleUtterance({required this.fromUserId, required this.text, required this.tStartMs});
  final String fromUserId;
  final String text;
  final int tStartMs;
}

/// 배틀 방 컨트롤러 — /ws/room 연결·상태머신·실통화 오디오 릴레이·발화(자막)를 소유.
/// 음성은 원본 PCM을 바이너리 프레임으로 서버가 상대에게 중계(실시간 통화),
/// 텍스트 utterance는 자막·심판용으로만 흐른다 (TTS 재생 없음).
/// 매칭 화면이 생성·[register], 브리핑/통화/결과 화면이 [of]로 조회(라우트 param 기준).
/// 서버 상태: matched → briefing → in_call → judging → done.
class BattleRoomController extends ChangeNotifier {
  BattleRoomController({
    required this.match,
    required this.myUserId,
  });

  // ---- roomId → 컨트롤러 레지스트리 (세션 스코프 인메모리) ----
  static final Map<String, BattleRoomController> _registry = {};

  static BattleRoomController? of(String roomId) => _registry[roomId];

  static void register(BattleRoomController c) => _registry[c.match.roomId] = c;

  /// 결과 화면 이탈 시 호출 — dispose까지 책임.
  static void unregister(String roomId) => _registry.remove(roomId)?.dispose();

  final BattleMatch match;
  final String myUserId;
  final PcmStreamPlayer _player = PcmStreamPlayer(); // 상대 음성 실시간 재생

  WebSocketChannel? _channel;
  bool _disposed = false;

  String state = 'matched'; // 서버 state 메시지 그대로
  bool readySent = false;
  final List<BattleUtterance> utterances = [];
  Map<String, dynamic>? verdict; // 서버 verdict 메시지 (judging → done 사이 도착)
  DateTime? _callStartedAt; // in_call 진입 시각 — tStartMs 기준점(규칙 #3)

  bool get inCall => state == 'in_call';
  bool get ended => state == 'judging' || state == 'done';
  int get elapsedMs =>
      _callStartedAt == null ? 0 : DateTime.now().difference(_callStartedAt!).inMilliseconds;
  int get elapsedSeconds => elapsedMs ~/ 1000;

  /// 방 소켓 연결 — 매칭 직후 1회. 서버 메시지를 상태로 반영.
  void connect() {
    if (_channel != null) return;
    PcmStreamPlayer.ensureEngine(); // 통화 시작(in_call) 전 미리 초기화 (브리핑 동안)
    final ch = GameServerClient().connectRoomSocket(roomId: match.roomId);
    _channel = ch;
    ch.stream.listen(
      _onMessage,
      onError: (_) {}, // 끊김은 onDone에서 일괄 처리
      onDone: () {
        _channel = null;
        // 판정 전 끊김 — 화면이 재시도/이탈을 안내할 수 있게 상태만 남긴다.
        if (!ended && !_disposed) {
          state = 'disconnected';
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    // 바이너리 = 상대 음성 PCM — 즉시 재생 큐로 (실통화 경로).
    if (raw is! String) {
      _player.feed(raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>));
      return;
    }
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'state':
        state = msg['state'] as String? ?? state;
        if (state == 'in_call') {
          _callStartedAt ??= DateTime.now();
          _player.start(); // 통화 시작 — 수신 오디오 재생 개시
        }
        notifyListeners();
      case 'utterance': // 자막·심판용 텍스트 (재생은 위 바이너리 경로가 담당)
        final u = BattleUtterance(
          fromUserId: msg['from'] as String? ?? '',
          text: msg['text'] as String? ?? '',
          tStartMs: (msg['tStartMs'] as num?)?.toInt() ?? 0,
        );
        if (u.text.isEmpty) return;
        utterances.add(u);
        notifyListeners();
      case 'verdict':
        verdict = msg;
        notifyListeners();
    }
  }

  void _send(Map<String, dynamic> msg) =>
      _channel?.sink.add(jsonEncode(msg));

  /// 내 마이크 PCM 청크를 상대에게 릴레이 (통화 중에만).
  void sendAudio(List<int> bytes) {
    if (!inCall || _disposed) return;
    _channel?.sink
        .add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  /// 브리핑 준비 완료 — 양측 모두 보내면 서버가 in_call로 전환.
  void sendReady() {
    if (readySent) return;
    readySent = true;
    _send({'type': 'ready'});
    notifyListeners();
  }

  /// 내 STT 확정 텍스트 전송. [tStartMs]는 발화 시작(PTT 누름) 시각 — 규칙 #3.
  void sendUtterance(String text, {required int tStartMs}) {
    final t = text.trim();
    if (t.isEmpty || !inCall) return;
    _send({'type': 'utterance', 'text': t, 'tStartMs': tStartMs});
  }

  void hangUp() => _send({'type': 'hang_up'});

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _player.dispose();
    super.dispose();
  }
}
