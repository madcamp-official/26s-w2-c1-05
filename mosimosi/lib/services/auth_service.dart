import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'game_server_client.dart';

/// 소셜 로그인 결과 — 서버 loopback 콜백 쿼리 그대로.
class AuthResult {
  AuthResult(
      {required this.token,
      required this.userId,
      this.nickname,
      required this.isNew});

  final String token;
  final String userId;
  final String? nickname; // null = 닉네임 미설정 → 온보딩 닉네임 단계 필요
  final bool isNew;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 브라우저 OAuth + loopback 수신 (Android·Windows 공통, 서버 auth.py와 계약).
/// 127.0.0.1 리스너를 열고 브라우저로 서버 /auth/{provider}/start를 띄우면,
/// 서버가 프로바이더 인증을 끝내고 http://127.0.0.1:{port}/callback?token=…으로
/// 돌려보낸다.
class AuthService {
  static const _timeout = Duration(minutes: 3);

  /// [provider]: 'google' | 'kakao'. 취소·실패는 [AuthException].
  Future<AuthResult> signIn(String provider) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final startUrl =
          Uri.parse('$gameServerUrl/auth/$provider/start?port=${server.port}');
      if (!await launchUrl(startUrl, mode: LaunchMode.externalApplication)) {
        throw AuthException('브라우저를 열 수 없어요');
      }
      final params = await _waitCallback(server).timeout(_timeout,
          onTimeout: () =>
              throw AuthException('로그인 시간이 초과됐어요 — 다시 시도해 주세요'));
      final error = params['error'];
      if (error != null) {
        throw AuthException(
            error == 'cancelled' ? '로그인이 취소됐어요' : '로그인에 실패했어요 ($error)');
      }
      final token = params['token'];
      final userId = params['user_id'];
      if (token == null || userId == null) {
        throw AuthException('로그인 응답이 올바르지 않아요');
      }
      return AuthResult(
        token: token,
        userId: userId,
        nickname: params['nickname'],
        isNew: params['is_new'] == 'true',
      );
    } finally {
      await server.close(force: true);
    }
  }

  /// /callback 요청이 올 때까지 대기 (favicon 등 잡요청은 404로 무시).
  Future<Map<String, String>> _waitCallback(HttpServer server) async {
    await for (final req in server) {
      if (req.uri.path != '/callback') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        continue;
      }
      final params = req.uri.queryParameters;
      final ok = params['error'] == null;
      req.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      req.response.write(
          '<html><body style="font-family:sans-serif;text-align:center;padding-top:80px">'
          '<h2>${ok ? '로그인 완료' : '로그인 실패'}</h2>'
          '<p>앱으로 돌아가세요. 이 창은 닫아도 돼요.</p></body></html>');
      await req.response.close();
      return params;
    }
    throw AuthException('로그인이 중단됐어요');
  }
}
