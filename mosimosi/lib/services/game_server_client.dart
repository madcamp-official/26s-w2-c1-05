import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// 게임 서버 주소 — 터널 고정 도메인 (필요 시 dart-define 오버라이드).
/// LLM 프록시(llm_factory)와 REST/WS가 같은 서버라 여기서 단일 관리.
const String gameServerUrl = String.fromEnvironment(
  'GAME_SERVER_URL',
  defaultValue: 'https://graceheeseo.madcamp-kaist.org',
);

/// 서버가 2xx 외 응답 — statusCode로 분기 (예: POST /users 409 = 닉네임 중복).
class GameServerException implements Exception {
  GameServerException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'GameServerException($statusCode): $body';
}

/// 게임 서버 클라이언트.
/// REST: 유저·도감·전적 / WebSocket: 매칭·배틀 방·타이머·트랜스크립트 수집.
class GameServerClient {
  GameServerClient({this.baseUrl = gameServerUrl});

  /// 예: `https://host` (WebSocket은 ws 스킴으로 변환해 사용)
  final String baseUrl;

  static const _timeout = Duration(seconds: 10);

  // --- REST ---
  Future<Map<String, dynamic>> getJson(String path) async =>
      await _decode(await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout))
          as Map<String, dynamic>;

  /// 배열 응답 엔드포인트용 (GET /users/{id}/progress, /users/{id}/sessions).
  Future<List<dynamic>> getJsonList(String path) async =>
      await _decode(await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout))
          as List<dynamic>;

  Future<Map<String, dynamic>> postJson(String path, Object? body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          // 한글 포함 → UTF-8 바이트로 명시 인코딩 (인코딩 모호성 제거).
          body: utf8.encode(jsonEncode(body)),
        )
        .timeout(_timeout);
    return _decode(response) as Map<String, dynamic>;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GameServerException(
          response.statusCode, utf8.decode(response.bodyBytes));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // --- WebSocket ---
  WebSocketChannel connectWebSocket(String path) {
    final wsBase = baseUrl.replaceFirst(RegExp('^http'), 'ws'); // http(s)→ws(s)
    return WebSocketChannel.connect(Uri.parse('$wsBase$path'));
  }
}
