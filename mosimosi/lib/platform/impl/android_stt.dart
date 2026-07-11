import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../stt_engine.dart';

/// Android 온디바이스 STT (`speech_to_text` 기반). interim/final 지원, 저지연.
/// Push-to-talk: [start] 로 인식 시작, [stop] 으로 최종 확정.
class AndroidSttEngine implements SttEngine {
  final SpeechToText _speech = SpeechToText();
  final StreamController<SttResult> _controller =
      StreamController<SttResult>.broadcast();

  bool _available = false;
  DateTime? _startedAt; // 이번 발화 시작 시각 (tStartMs 기준점)

  @override
  Stream<SttResult> get results => _controller.stream;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> initialize() async {
    _available = await _speech.initialize(
      onError: (e) => _available = _available && !e.permanent,
    );
    return _available;
  }

  @override
  Future<void> start() async {
    if (!_available) return;
    _startedAt = DateTime.now();
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        // Push-to-talk: 자동 종료 방지. 종료는 stop() 으로만.
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(minutes: 1),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  void _onResult(SpeechRecognitionResult result) {
    if (_controller.isClosed) return;
    _controller.add(SttResult(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      tStartMs:
          DateTime.now().difference(_startedAt ?? DateTime.now()).inMilliseconds,
    ));
  }
}
