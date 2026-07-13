/// STT 인식 결과 한 건.
class SttResult {
  const SttResult({
    required this.text,
    required this.isFinal,
    required this.tStartMs,
  });

  final String text;
  final bool isFinal;

  /// 발화 시작 시각 (통화 시작 = 0 기준 상대 ms). 채점은 이 값 기준.
  final int tStartMs;
}

abstract class SttEngine {
  Stream<SttResult> get results; // SttResult{text, isFinal, tStartMs}

  /// 엔진 준비(권한 요청 포함). 사용 가능 여부를 반환. 온보딩 0.2에서도 사용.
  Future<bool> initialize();

  Future<void> start();
  Future<void> stop();

  /// 반이중 에코 게이트 — TTS 재생 동안 true로 캡처 오디오 전송을 차단한다
  /// (스피커 출력이 마이크로 되먹임돼 상대/보스 말이 내 발화로 전사되는 것 방지).
  void setMuted(bool muted);

  /// 캡처 원본 오디오 탭 (16kHz mono PCM16, 뮤트와 무관) — 배틀 실통화가
  /// 이 스트림을 방 소켓으로 릴레이한다. 마이크는 한 번만 열어 공유(이중 점유 방지).
  Stream<List<int>> get rawAudio;

  bool get isAvailable; // false면 UI가 텍스트 입력 폴백 표시
}
