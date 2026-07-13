import 'package:record/record.dart' as rec;

import '../audio_recorder.dart';

/// `record` 플러그인 기반 마이크 캡처. 16kHz mono PCM16 청크 스트림.
/// 데스크톱 STT(서버 Whisper) + Whisper 정제 트랙용.
class RecordAudioRecorder implements AudioRecorder {
  final rec.AudioRecorder _recorder = rec.AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Stream<List<int>> startChunks() async* {
    final stream = await _recorder.startStream(const rec.RecordConfig(
      encoder: rec.AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    yield* stream;
  }

  @override
  Future<void> stop() => _recorder.stop();
}
