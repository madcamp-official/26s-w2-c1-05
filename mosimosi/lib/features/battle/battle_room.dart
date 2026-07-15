import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../platform/pcm_player.dart';
import '../../services/game_server_client.dart';

/// 매칭 성사 페이로드 — 서버 /ws/match `matched` 이벤트의 자기 몫(규칙 #2).
/// 시나리오 5필드 브리핑(당신의 상황·목표·승패·물러설 수 없는 선+예외·비밀)을
/// 서버가 역할별로 내려준다. 라벨(판매자/구매자 등)도 데이터로 온다.
class BattleMatch {
  const BattleMatch({
    required this.roomId,
    required this.role,
    required this.scenarioTitle,
    required this.situation,
    required this.roleLabel,
    required this.opponentLabel,
    required this.personal,
    required this.goal,
    required this.winNote,
    required this.hardLine,
    required this.exceptions,
    required this.secret,
    required this.chipGoal,
    required this.chipLine,
    required this.chipSecret,
    required this.openingLine,
    required this.opponentNickname,
    required this.opponentFormFactor,
  });

  final String roomId;
  final String role; // 'agent'(역할 A) | 'claimant'(역할 B) — 슬롯 식별용
  final String scenarioTitle;
  final String situation; // 공통 상황
  final String roleLabel; // 내 역할명 (판매자 등)
  final String opponentLabel; // 상대 역할명 (구매자 등)
  final String personal; // 당신의 상황
  final String goal; // 목표
  final String winNote; // 승패 기준
  final String hardLine; // 물러설 수 없는 선
  final List<String> exceptions; // 선을 움직이는 조건부 예외
  final String secret; // 들키면 안 되는 비밀
  final String chipGoal; // 통화 칩 — 목표
  final String chipLine; // 통화 칩 — 선
  final String chipSecret; // 통화 칩 — 비밀
  final String openingLine; // 침묵 지속 시 제안할 내 몫의 첫마디
  final String opponentNickname;
  final String opponentFormFactor; // 'android' | 'windows'

  bool get isAgent => role == 'agent';

  factory BattleMatch.fromJson(Map<String, dynamic> j) {
    final chip = j['chip'] as Map<String, dynamic>? ?? const {};
    return BattleMatch(
      roomId: j['roomId'] as String,
      role: j['role'] as String,
      scenarioTitle: j['scenarioTitle'] as String? ?? '배틀',
      situation: j['situation'] as String? ?? '',
      roleLabel: j['roleLabel'] as String? ?? '나',
      opponentLabel: j['opponentLabel'] as String? ?? '상대',
      personal: j['personal'] as String? ?? '',
      goal: j['goal'] as String? ?? '',
      winNote: j['winNote'] as String? ?? '',
      hardLine: j['hardLine'] as String? ?? '',
      exceptions: (j['exceptions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      secret: j['secret'] as String? ?? '',
      chipGoal: chip['goal'] as String? ?? '',
      chipLine: chip['line'] as String? ?? '',
      chipSecret: chip['secret'] as String? ?? '',
      openingLine: j['openingLine'] as String? ?? '',
      opponentNickname:
          (j['opponent'] as Map<String, dynamic>?)?['nickname'] as String? ?? '상대',
      opponentFormFactor:
          (j['opponent'] as Map<String, dynamic>?)?['formFactor'] as String? ?? 'android',
    );
  }
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
  // ---- 인크리멘탈 심판 (실시간 게임 층 — 참고 지표, 최종 승패는 종료 후 심판) ----
  int myMomentum = 50; // 내 관점 기세 0~100
  int judgeSeq = 0; // 판정 도착 감지용 (화면 팝업 트리거)
  String? judgeEvent; // 최근 판정의 이벤트 문구 (null = 이벤트 없음)
  String myHint = ''; // 내 전용 AI 코치 귓속말 (최신 유지)
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
      case 'judge': // 인크리멘탈 심판 — 기세·이벤트·코치 (힌트는 서버가 내 몫만 전송)
        myMomentum = (msg['momentum'] as num?)?.round() ?? myMomentum;
        judgeSeq = (msg['seq'] as num?)?.toInt() ?? judgeSeq + 1;
        judgeEvent = msg['event'] as String?;
        final hint = msg['hint'] as String? ?? '';
        if (hint.isNotEmpty) myHint = hint;
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
