import 'llm_client.dart';

/// 자체 서빙 vLLM (Qwen3-14B AWQ, OpenAI 호환 API).
/// 담당: 보스 대화 턴, 인크리멘탈 심판.
class VllmClient implements LlmClient {
  @override
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    double? temperature,
    int? maxOutputTokens,
  }) =>
      throw UnimplementedError();
}
