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
  bool get isAvailable; // false면 UI가 텍스트 입력 폴백 표시
}
