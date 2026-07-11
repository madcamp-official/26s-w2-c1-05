import 'gemini_client.dart';
import 'llm_client.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// LLM 구현체 선택 지점 (규칙 #4: `LLM_FALLBACK=gemini` 전환 자리).
/// vLLM 서버 준비 전이라 현재는 전 태스크 Gemini. 서버가 올라오면
/// 보스 대화 턴을 VllmClient로 배분하고 여기서 분기한다.
LlmClient createLlmClient() => GeminiClient(apiKey: _geminiApiKey);
