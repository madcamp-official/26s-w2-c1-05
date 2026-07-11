import 'game_server_client.dart';
import 'llm_client.dart';
import 'proxy_llm_client.dart';

/// LLM 구현체 선택 지점 (규칙 #4: 클라이언트는 프록시 경유, 키는 서버에만).
/// 서버가 task별로 vLLM(보스 대화)·Gemini(심판·시나리오)를 분기하고,
/// `LLM_FALLBACK=gemini`(서버 env)로 전량 Gemini 전환도 서버에서 처리.
/// 서버 주소는 REST/WS와 공유 — [gameServerUrl] (game_server_client.dart).
LlmClient createLlmClient() => ProxyLlmClient(baseUrl: gameServerUrl);
