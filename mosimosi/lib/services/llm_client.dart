/// OpenAI 호환 chat 메시지.
class LlmMessage {
  const LlmMessage({required this.role, required this.content});

  final String role; // system | user | assistant
  final String content;
}

/// LLM 호출 추상화. 클라이언트는 게임 서버 프록시 경유(API 키는 서버에만).
/// `LLM_FALLBACK=gemini` 시 전 태스크가 Gemini 구현체로 전환 가능해야 함.
abstract class LlmClient {
  /// 응답 텍스트를 스트리밍으로 수신 (첫 문장 완성 즉시 TTS 시작용).
  /// [temperature]/[maxOutputTokens]는 태스크별 오버라이드 (심판=저온·장문 등).
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    double? temperature,
    int? maxOutputTokens,
  });
}
