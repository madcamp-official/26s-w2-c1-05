import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../services/game_server_client.dart';

/// 관전 발화 한 건 (역할 표기 — 관전자는 user_id·비밀을 받지 않는다).
class WatchUtterance {
  const WatchUtterance({required this.role, required this.text});
  final String role; // 'agent' | 'claimant'
  final String text;
}

/// 관전 컨트롤러 (데모 프로젝터용, 읽기 전용) — /ws/watch/{roomId} 구독.
/// 서버 watch_init 스냅샷으로 중간 진입을 채우고, 이후 state/utterance/judge를
/// 반영한다. 발화는 역할별로 분리해 양측 폰에 표시.
class BattleWatchController extends ChangeNotifier {
  BattleWatchController({required this.roomId});

  final String roomId;
  WebSocketChannel? _channel;
  bool _disposed = false;

  String state = 'in_call';
  int momentumAgent = 50; // agent 관점 0~100
  DateTime? _startedAt; // 통화 시작 추정 (경과 시간 표시용)
  String agentNick = '역할 A';
  String claimantNick = '역할 B';
  String agentLabel = '역할 A'; // 시나리오 역할명 (판매자 등)
  String claimantLabel = '역할 B';
  String agentSecret = ''; // 감독 시점 — 양측 비밀 노출
  String claimantSecret = '';
  final List<WatchUtterance> agentLine = []; // agent 발화
  final List<WatchUtterance> claimantLine = []; // claimant 발화

  int get elapsedSeconds =>
      _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds;
  bool get ended => state == 'judging' || state == 'done';

  void connect() {
    if (_channel != null) return;
    final ch = GameServerClient().connectWatchSocket(roomId: roomId);
    _channel = ch;
    ch.stream.listen(_onMessage,
        onError: (_) {},
        onDone: () {
          _channel = null;
          if (!_disposed) {
            state = 'disconnected';
            notifyListeners();
          }
        },
        cancelOnError: false);
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'watch_init':
        state = msg['state'] as String? ?? state;
        final startedAtMs = (msg['startedAtMs'] as num?)?.toInt() ?? 0;
        _startedAt = DateTime.now().subtract(Duration(milliseconds: startedAtMs));
        final players = msg['players'] as Map<String, dynamic>? ?? {};
        final agent = players['agent'] as Map?;
        final claimant = players['claimant'] as Map?;
        agentNick = agent?['nickname'] as String? ?? '역할 A';
        claimantNick = claimant?['nickname'] as String? ?? '역할 B';
        agentLabel = agent?['roleLabel'] as String? ?? '역할 A';
        claimantLabel = claimant?['roleLabel'] as String? ?? '역할 B';
        agentSecret = agent?['secret'] as String? ?? agent?['secretGoal'] as String? ?? '';
        claimantSecret = claimant?['secret'] as String? ?? claimant?['secretGoal'] as String? ?? '';
        final mom = msg['momentum'] as Map<String, dynamic>?;
        if (mom != null) momentumAgent = (mom['agent'] as num?)?.round() ?? 50;
        agentLine.clear();
        claimantLine.clear();
        for (final u in (msg['utterances'] as List? ?? const [])) {
          _addUtterance(u as Map<String, dynamic>);
        }
        notifyListeners();
      case 'state':
        state = msg['state'] as String? ?? state;
        if (state == 'in_call') _startedAt ??= DateTime.now();
        notifyListeners();
      case 'utterance':
        _addUtterance(msg);
        notifyListeners();
      case 'judge':
        momentumAgent = (msg['momentumAgent'] as num?)?.round() ?? momentumAgent;
        notifyListeners();
    }
  }

  void _addUtterance(Map<String, dynamic> m) {
    final role = m['role'] as String? ?? '';
    final text = (m['text'] as String? ?? '').trim();
    if (text.isEmpty) return;
    (role == 'agent' ? agentLine : claimantLine)
        .add(WatchUtterance(role: role, text: text));
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
