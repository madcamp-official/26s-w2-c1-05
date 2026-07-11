import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'impl/android_stt.dart';
import 'impl/desktop_stt.dart';
import 'impl/record_audio_recorder.dart';
import 'stt_engine.dart';

/// 플랫폼 감지로 STT 구현체 선택. 구현체 선택은 반드시 여기서만.
SttEngine createSttEngine() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSttEngine();
  }
  // 데스크톱: record → WebSocket → 서버 faster-whisper.
  return DesktopSttEngine(
    whisperUrl: dotenv.env['WHISPER_WS_URL'] ?? '',
    recorder: RecordAudioRecorder(),
  );
}
