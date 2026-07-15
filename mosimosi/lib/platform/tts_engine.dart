abstract class TtsEngine {
  /// [emotion]: '평온'|'상냥'|'짜증'|'분노'|'미안'|'당황' 중 하나 또는 null.
  /// 서버 TTS(Qwen)만 감정을 반영하고, OS 폴백은 무시한다.
  Future<void> speak(String text, {double pitch, double rate, String? emotion});
  Future<void> stopSpeaking();
}
