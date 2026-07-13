import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'impl/record_audio_recorder.dart';
import 'impl/whisper_stt.dart';
import 'stt_engine.dart';

/// STT 구현체는 이제 플랫폼 무관 단일 구현(record → WebSocket → 서버
/// faster-whisper) — Android 온디바이스 STT는 폐지(오디오 릴레이·오픈마이크를
/// 위해 raw PCM 캡처가 필요해 record 기반으로 통일).
SttEngine createSttEngine() => WhisperSttEngine(
      whisperUrl: dotenv.env['WHISPER_WS_URL'] ?? '',
      recorder: RecordAudioRecorder(),
    );
