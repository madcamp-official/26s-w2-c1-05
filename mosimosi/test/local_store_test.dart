import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('상대방 자막은 기본으로 꺼져 있고 설정값을 저장한다', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();

    expect(LocalStore.instance.showOpponentCaptions, isFalse);

    await LocalStore.instance.saveShowOpponentCaptions(true);
    expect(LocalStore.instance.showOpponentCaptions, isTrue);
  });
}
