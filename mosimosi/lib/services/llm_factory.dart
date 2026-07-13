import 'fake_llm_client.dart';
import 'game_server_client.dart';
import 'llm_client.dart';
import 'proxy_llm_client.dart';

/// LLM 구현체 선택 지점 (규칙 #4: 클라이언트는 프록시 경유, 키는 서버에만).
/// 서버가 task별로 vLLM(보스 대화)·Gemini(심판·시나리오)를 분기하고,
/// `LLM_FALLBACK=gemini`(서버 env)로 전량 Gemini 전환도 서버에서 처리.
/// 서버 주소는 REST/WS와 공유 — [gameServerUrl] (game_server_client.dart).
///
/// 개발용: `--dart-define=USE_FAKE_LLM=true` 시 서버 없이 가짜 LLM으로 구동
/// (프록시 미가동·장애 시 데스크톱 E2E 테스트). 기본값 false — 평소엔 비활성.
LlmClient createLlmClient() => const bool.fromEnvironment('USE_FAKE_LLM')
    ? const FakeLlmClient()
    : ProxyLlmClient(baseUrl: gameServerUrl);
