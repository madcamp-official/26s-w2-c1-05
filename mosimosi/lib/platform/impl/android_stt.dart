import '../stt_engine.dart';

/// Android 온디바이스 STT (`speech_to_text` 기반). Day 1 스파이크에서 구현.
class AndroidSttEngine implements SttEngine {
  @override
  Stream<SttResult> get results => throw UnimplementedError();

  @override
  Future<void> start() => throw UnimplementedError();

  @override
  Future<void> stop() => throw UnimplementedError();

  @override
  bool get isAvailable => false;
}
