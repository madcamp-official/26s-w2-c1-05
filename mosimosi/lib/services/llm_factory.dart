import 'llm_client.dart';
import 'proxy_llm_client.dart';

/// 게임 서버 주소. 터널 고정 도메인이라 기본값으로 충분 (필요 시 dart-define 오버라이드).
const String _gameServerUrl = String.fromEnvironment(
  'GAME_SERVER_URL',
  defaultValue: 'https://graceheeseo.madcamp-kaist.org',
);

/// LLM 구현체 선택 지점 (규칙 #4: 클라이언트는 프록시 경유, 키는 서버에만).
/// 서버가 task별로 vLLM(보스 대화)·Gemini(심판·시나리오)를 분기하고,
/// `LLM_FALLBACK=gemini`(서버 env)로 전량 Gemini 전환도 서버에서 처리.
LlmClient createLlmClient() => ProxyLlmClient(baseUrl: _gameServerUrl);
