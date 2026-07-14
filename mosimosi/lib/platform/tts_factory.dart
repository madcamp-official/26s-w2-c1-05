import '../core/models/boss.dart';
import 'impl/cloud_tts_engine.dart';
import 'impl/flutter_tts_engine.dart';
import 'tts_engine.dart';

/// TTS 구현체 선택. [voicePreset]이 주어지면 서버 `/tts/synthesize`(Google Cloud
/// TTS) 기반 [CloudTtsEngine]을 쓰고(실패 시 내부적으로 flutter_tts 폴백),
/// 없으면(보스 없는 화면 등) 기존 OS 내장 [FlutterTtsEngine] 그대로 사용.
TtsEngine createTtsEngine({TtsVoicePreset? voicePreset}) => voicePreset == null
    ? FlutterTtsEngine()
    : CloudTtsEngine(voicePreset: voicePreset);
