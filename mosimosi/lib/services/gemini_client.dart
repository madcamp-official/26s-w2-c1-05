import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';
import 'llm_logger.dart';

/// Gemini 2.5 Flash. 담당: 최종 심판, 리포트, 시나리오 생성 (+ 전량 폴백).
///
/// ⚠️ Day 1 스파이크 한정: 앱에서 Gemini를 직접 호출한다. 프로덕션에서는
/// Instructions.md 규칙 #4대로 게임 서버 프록시 경유로 교체해야 한다(키 은닉).
/// API 키는 하드코딩 금지 — `--dart-define=GEMINI_API_KEY=...` 로 주입.
class GeminiClient implements LlmClient {
  // FSD §6.2는 'gemini-2.5-flash'를 명시하나 이 키(신규 프로젝트)에선:
  //  - gemini-2.5-flash / -lite : 404 (신규 사용자 차단)
  //  - gemini-flash-latest(=3.5-flash) : 200이나 무료 티어 스로틀로 11~21s (사용 불가)
  //  - gemini-flash-lite-latest : 200, ~0.8s ← 채택 (Day 1 스파이크 지연 목표 충족)
  // 대화 턴은 프로덕션에서 자체 vLLM(Qwen3-14B)로 감 — Gemini는 스파이크 임시 대역.
  GeminiClient({
    required this.apiKey,
    this.model = 'gemini-flash-lite-latest',
    LlmLogger? logger,
  }) : _logger = logger ?? LlmLogger();

  final String apiKey;
  final String model;
  final LlmLogger _logger;

  @override
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    String task = 'boss_turn', // 직접 호출 시 무시 (분기는 서버 프록시 몫)
    double? temperature,
    int? maxOutputTokens,
  }) async* {
    final systemText = messages
        .where((m) => m.role == 'system')
        .map((m) => m.content)
        .join('\n');
    final contents = messages
        .where((m) => m.role != 'system')
        .map((m) => {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': m.content}
              ],
            })
        .toList();

    final body = <String, dynamic>{
      if (systemText.isNotEmpty)
        'system_instruction': {
          'parts': [
            {'text': systemText}
          ]
        },
      'contents': contents,
      'generationConfig': {
        'temperature': temperature ?? 0.9,
        'maxOutputTokens': maxOutputTokens ?? 256,
        // 저지연 목표(1.5s) — 기본 thinking 비활성화.
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };
    await _logger.log({'type': 'request', 'model': model, 'body': body});

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:streamGenerateContent?alt=sse&key=$apiKey',
    );
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        await _logger.log(
            {'type': 'error', 'status': response.statusCode, 'body': errBody});
        throw Exception('Gemini ${response.statusCode}: $errBody');
      }

      final full = StringBuffer();
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;

        final json = jsonDecode(data) as Map<String, dynamic>;
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;
        final parts =
            (candidates[0]['content']?['parts'] as List?) ?? const [];
        for (final part in parts) {
          final text = part['text'];
          if (text is String && text.isNotEmpty) {
            full.write(text);
            yield text;
          }
        }
      }
      await _logger.log({'type': 'response', 'model': model, 'text': full.toString()});
    } finally {
      client.close();
    }
  }
}
