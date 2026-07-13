import 'package:flutter_tts/flutter_tts.dart';

import '../tts_engine.dart';

/// OS 내장 TTS (`flutter_tts`). Android/Wind(SAPI) 공통 — FSD §5.1.
/// [speak] 은 발화 완료 시 완료(awaitSpeakCompletion) → 문장 큐잉 재생에 사용.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('ko-KR');
    _ready = true;
  }

  @override
  Future<void> speak(String text, {double pitch = 1.0, double rate = 0.5}) async {
    await _ensureReady();
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<void> stopSpeaking() => _tts.stop();
}
