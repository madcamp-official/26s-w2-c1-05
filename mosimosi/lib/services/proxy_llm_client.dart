import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_client.dart';

/// 게임 서버 LLM 프록시 경유 (Instructions.md 규칙 #4: API 키는 서버에만).
///
/// `POST {baseUrl}/llm/chat` → 서버가 [task]로 백엔드 분기
/// (boss_turn·incremental→vLLM / final_judge·scenario→Gemini, FSD §6.2).
/// 응답은 SSE: `data: {"text":"..."}` … `data: [DONE]`.
class ProxyLlmClient implements LlmClient {
  ProxyLlmClient({required this.baseUrl});

  /// 예: https://graceheeseo.madcamp-kaist.org
  final String baseUrl;

  @override
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    String task = 'boss_turn',
    double? temperature,
    int? maxOutputTokens,
  }) async* {
    final payload = <String, dynamic>{
      'task': task,
      'messages': [
        for (final m in messages) {'role': m.role, 'content': m.content},
      ],
      'temperature': ?temperature,
      'max_output_tokens': ?maxOutputTokens,
    };

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/llm/chat'))
        ..headers['Content-Type'] = 'application/json'
        // 한글 포함 → UTF-8 바이트로 명시 인코딩 (인코딩 모호성 제거).
        ..bodyBytes = utf8.encode(jsonEncode(payload));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        throw Exception('LLM proxy ${response.statusCode}: $errBody');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        final json = jsonDecode(data) as Map<String, dynamic>;
        final text = json['text'];
        if (text is String && text.isNotEmpty) yield text;
      }
    } finally {
      client.close();
    }
  }
}
