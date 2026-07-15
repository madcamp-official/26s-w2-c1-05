import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'core/local_store.dart';
import 'core/router.dart';
import 'core/sound_service.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // just_audio는 Windows/Linux 기본 구현이 없어 media_kit으로 보강한다.
  // 기본값이 windows/linux만 켜고 android/iOS/macOS는 그대로 둬서 기존
  // 네이티브 구현에 영향 없음(패키지 자체 기본 인자 확인 완료).
  JustAudioMediaKit.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env 없거나 로드 실패 시 데스크톱 Whisper 미설정 → 폴백 UI로 동작.
  }
  await LocalStore.init();
  SoundService.instance.init(); // 효과음·BGM 엔진 프리로드 (실패해도 무해)
  // 로그인 토큰 + 닉네임까지 있어야 온보딩 통과 (닉네임 미설정 = 온보딩 중단분).
  final store = LocalStore.instance;
  final router = buildRouter(
    initialLocation:
        store.hasUser && store.nickname != null ? '/home' : '/onboarding',
  );
  runApp(ProviderScope(child: MainApp(router: router)));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '여보세요',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
