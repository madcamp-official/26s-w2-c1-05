import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/core/models/boss.dart';
import 'package:mosimosi/platform/impl/cloud_tts_engine.dart';
import 'package:mosimosi/platform/impl/flutter_tts_engine.dart';
import 'package:mosimosi/platform/tts_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voicePreset 없으면 FlutterTtsEngine(OS 내장)을 쓴다', () {
    expect(createTtsEngine(), isA<FlutterTtsEngine>());
  });

  test('voicePreset이 있으면 CloudTtsEngine을 쓴다', () {
    const preset = TtsVoicePreset(voiceName: 'ko-KR-Chirp3-HD-Charon');
    expect(createTtsEngine(voicePreset: preset), isA<CloudTtsEngine>());
  });
}
