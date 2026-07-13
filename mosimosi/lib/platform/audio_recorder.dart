abstract class AudioRecorder {
  // 데스크톱 STT + Whisper 정제 트랙용
  /// 마이크 권한 확인(미허용 시 OS 요청까지 포함). startChunks() 전에 반드시 확인.
  Future<bool> hasPermission();
  Stream<List<int>> startChunks(); // 오디오 청크 스트림
  Future<void> stop();
}
