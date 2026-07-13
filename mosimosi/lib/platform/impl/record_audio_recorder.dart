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
      // 오픈마이크 필수: 노이즈 바닥을 낮춰 서버 VAD의 침묵 판정을 가능하게 하고
      // (2026-07-13 무응답 버그 원인), 에코 캔슬은 스피커 출력(보스 TTS·배틀
      // 상대 음성)이 마이크로 되먹임돼 내 발화로 전사되는 것을 방지.
      echoCancel: true,
      noiseSuppress: true,
      // Android AEC는 VOICE_COMMUNICATION 캡처 경로에서만 실효성이 보장됨
      // (echoCancel 단독으론 DEFAULT 소스라 기기 의존) — 통화 앱 표준 조합.
      androidConfig: rec.AndroidRecordConfig(
        audioSource: rec.AndroidAudioSource.voiceCommunication,
        audioManagerMode: rec.AudioManagerMode.modeInCommunication,
        speakerphone: true,
      ),
    ));
    yield* stream;
  }

  @override
  Future<void> stop() => _recorder.stop();
}
