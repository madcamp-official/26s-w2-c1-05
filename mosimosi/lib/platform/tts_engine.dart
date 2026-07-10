abstract class TtsEngine {
  Future<void> speak(String text, {double pitch, double rate});
  Future<void> stopSpeaking();
}
