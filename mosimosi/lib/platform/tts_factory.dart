import 'impl/flutter_tts_engine.dart';
import 'tts_engine.dart';

/// TTS 구현체 선택. flutter_tts는 Android/Windows 공통(FSD §5.1)이라 단일 구현체.
TtsEngine createTtsEngine() => FlutterTtsEngine();
