abstract class AudioRecorder {
  // 데스크톱 STT + Whisper 정제 트랙용
  Stream<List<int>> startChunks(); // 오디오 청크 스트림
  Future<void> stop();
}
