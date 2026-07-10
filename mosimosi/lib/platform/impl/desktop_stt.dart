import '../stt_engine.dart';

/// 데스크톱 STT: `record` 오디오 캡처 → WebSocket → 서버 faster-whisper.
/// Day 1 스파이크에서 구현.
class DesktopSttEngine implements SttEngine {
  @override
  Stream<SttResult> get results => throw UnimplementedError();

  @override
  Future<void> start() => throw UnimplementedError();

  @override
  Future<void> stop() => throw UnimplementedError();

  @override
  bool get isAvailable => false;
}
