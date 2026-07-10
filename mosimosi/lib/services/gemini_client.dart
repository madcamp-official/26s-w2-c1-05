import 'llm_client.dart';

/// Gemini 2.5 Flash. 담당: 최종 심판, 리포트, 시나리오 생성 (+ 전량 폴백).
class GeminiClient implements LlmClient {
  @override
  Stream<String> chatStream(List<LlmMessage> messages) =>
      throw UnimplementedError();
}
