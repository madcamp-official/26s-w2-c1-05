import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 영속 저장소 — user_id·nickname (Phase 2 §1).
/// main()에서 [init]을 await한 뒤 사용한다 (라우터 initialLocation 결정에 필요).
class LocalStore {
  LocalStore._(this._prefs);

  static const _kUserId = 'user_id';
  static const _kNickname = 'nickname';

  static LocalStore? _instance;
  static LocalStore get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('LocalStore.init()이 main()에서 호출되지 않았어요.');
    }
    return i;
  }

  static Future<void> init() async {
    _instance ??= LocalStore._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  String? get userId => _prefs.getString(_kUserId);
  String? get nickname => _prefs.getString(_kNickname);

  /// 온보딩 완료 여부 = user_id 존재.
  bool get hasUser => userId != null && userId!.isNotEmpty;

  Future<void> saveUser({required String userId, required String nickname}) async {
    await _prefs.setString(_kUserId, userId);
    await _prefs.setString(_kNickname, nickname);
  }
}
