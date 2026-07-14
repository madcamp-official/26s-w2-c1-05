import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 영속 저장소 — 로그인 토큰(JWT)은 OS 보안 저장소, 프로필은 prefs.
/// main()에서 [init]을 await한 뒤 사용한다 (라우터 initialLocation 결정에 필요).
class LocalStore {
  LocalStore._(this._prefs, this._token);

  static const _kUserId = 'user_id';
  static const _kNickname = 'nickname';
  static const _kToken = 'auth_token';
  static const _kOpenMic = 'open_mic';
  static const _kShowOpponentCaptions = 'show_opponent_captions';

  static const _secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static LocalStore? _instance;
  static LocalStore get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('LocalStore.init()이 main()에서 호출되지 않았어요.');
    }
    return i;
  }

  static Future<void> init() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    String? token;
    try {
      token = await _secure.read(key: _kToken);
    } catch (_) {
      token = null; // 보안 저장소 접근 실패 — 재로그인 유도
    }
    _instance = LocalStore._(prefs, token);
  }

  final SharedPreferences _prefs;
  String? _token;

  /// 서버 JWT — REST Authorization 헤더·WS token 파라미터에 사용.
  String? get token => _token;
  String? get userId => _prefs.getString(_kUserId);
  String? get nickname => _prefs.getString(_kNickname);

  /// 로그인 상태 = 토큰 존재. 닉네임(null 가능)은 온보딩 완료 판정에 별도 확인.
  bool get hasUser => _token != null && userId != null;

  /// 소셜 로그인 성공 — 토큰·프로필 저장 (nickname은 기존 계정만 내려옴).
  Future<void> saveAuth(
      {required String token, required String userId, String? nickname}) async {
    _token = token;
    await _secure.write(key: _kToken, value: token);
    await _prefs.setString(_kUserId, userId);
    if (nickname != null) await _prefs.setString(_kNickname, nickname);
  }

  Future<void> saveNickname(String nickname) async {
    await _prefs.setString(_kNickname, nickname);
  }

  /// 통화 발화 방식 — true(기본)=오픈마이크(상시 청취), false=눌러서 말하기(PTT).
  bool get openMic => _prefs.getBool(_kOpenMic) ?? true;

  Future<void> saveOpenMic(bool value) async {
    await _prefs.setBool(_kOpenMic, value);
  }

  /// 통화 중 상대방 자막 표시 여부 — 기본은 숨김.
  bool get showOpponentCaptions =>
      _prefs.getBool(_kShowOpponentCaptions) ?? false;

  Future<void> saveShowOpponentCaptions(bool value) async {
    await _prefs.setBool(_kShowOpponentCaptions, value);
  }

  /// 로그아웃·탈퇴 — 토큰·프로필 제거 (온보딩에서 새로 로그인).
  Future<void> clearAuth() async {
    _token = null;
    try {
      await _secure.delete(key: _kToken);
    } catch (_) {}
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kNickname);
  }
}
