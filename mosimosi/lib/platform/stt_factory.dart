import 'package:flutter/foundation.dart';

import 'impl/android_stt.dart';
import 'impl/desktop_stt.dart';
import 'stt_engine.dart';

/// 플랫폼 감지로 STT 구현체 선택. 구현체 선택은 반드시 여기서만.
SttEngine createSttEngine() {
  return defaultTargetPlatform == TargetPlatform.android
      ? AndroidSttEngine()
      : DesktopSttEngine();
}
