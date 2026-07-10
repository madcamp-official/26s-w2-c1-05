import 'package:web_socket_channel/web_socket_channel.dart';

/// 게임 서버 클라이언트.
/// REST: 도감·전적 / WebSocket: 매칭·배틀 방·타이머·트랜스크립트 수집.
class GameServerClient {
  GameServerClient({required this.baseUrl});

  /// 예: `http://host:port` (WebSocket은 ws 스킴으로 변환해 사용)
  final String baseUrl;

  // --- REST ---
  Future<Map<String, dynamic>> getJson(String path) =>
      throw UnimplementedError();

  Future<Map<String, dynamic>> postJson(String path, Object? body) =>
      throw UnimplementedError();

  // --- WebSocket ---
  WebSocketChannel connectWebSocket(String path) =>
      throw UnimplementedError();
}
