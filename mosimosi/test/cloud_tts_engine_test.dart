import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mosimosi/core/models/boss.dart';
import 'package:mosimosi/platform/impl/cloud_tts_engine.dart';
import 'package:mosimosi/platform/tts_engine.dart';

/// [CloudTtsEngine]이 폴백으로 전환하는지 기록하는 더미 TtsEngine.
class _FakeTtsEngine implements TtsEngine {
  final List<String> spoken = [];
  bool stopped = false;

  @override
  Future<void> speak(String text, {double pitch = 1.0, double rate = 0.5}) async {
    spoken.add(text);
  }

  @override
  Future<void> stopSpeaking() async {
    stopped = true;
  }
}

void main() {
  // AudioPlayer()/FlutterTts() 생성자가 내부적으로 MethodChannel 핸들러를 등록해서
  // WidgetsFlutterBinding 초기화가 필요하다(실제 채널 왕복은 아니라 이걸로 충분).
  TestWidgetsFlutterBinding.ensureInitialized();

  const preset = TtsVoicePreset(voiceName: 'ko-KR-Chirp3-HD-Charon', pace: 0.9);

  test('빈 텍스트는 네트워크 호출도 폴백도 없이 무시된다', () async {
    var called = false;
    final fallback = _FakeTtsEngine();
    final client = MockClient((_) async {
      called = true;
      return http.Response('', 200);
    });
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: fallback,
      playBytes: (_) async {},
    );
    await engine.speak('   ');
    expect(called, isFalse);
    expect(fallback.spoken, isEmpty);
  });

  test('200 응답이면 playBytes로 오디오를 넘기고 폴백은 안 씀', () async {
    final fallback = _FakeTtsEngine();
    final received = <int>[];
    final client = MockClient((req) async => http.Response.bytes([1, 2, 3], 200));
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: fallback,
      playBytes: (bytes) async => received.addAll(bytes),
    );
    await engine.speak('안녕하세요');
    expect(received, [1, 2, 3]);
    expect(fallback.spoken, isEmpty);
  });

  test('요청 페이로드가 보이스 프리셋을 정확히 반영한다 (pitch 없으면 생략)', () async {
    Map<String, dynamic>? sentBody;
    final client = MockClient((req) async {
      sentBody = jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
      return http.Response.bytes([9], 200);
    });
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: _FakeTtsEngine(),
      playBytes: (_) async {},
    );
    await engine.speak('고객님, 환불은 안 됩니다.');
    expect(sentBody!['text'], '고객님, 환불은 안 됩니다.');
    expect(sentBody!['voice_name'], 'ko-KR-Chirp3-HD-Charon');
    expect(sentBody!['pace'], 0.9);
    expect(sentBody!.containsKey('pitch'), isFalse);
  });

  test('pitch가 있으면 페이로드에 포함된다', () async {
    Map<String, dynamic>? sentBody;
    final client = MockClient((req) async {
      sentBody = jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
      return http.Response.bytes([9], 200);
    });
    final engine = CloudTtsEngine(
      voicePreset: const TtsVoicePreset(voiceName: 'ko-KR-Neural2-C', pitch: -3.5),
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: _FakeTtsEngine(),
      playBytes: (_) async {},
    );
    await engine.speak('테스트');
    expect(sentBody!['pitch'], -3.5);
  });

  test('서버가 5xx면 폴백으로 전환된다', () async {
    var playCalled = false;
    final fallback = _FakeTtsEngine();
    final client = MockClient((_) async => http.Response('service unavailable', 503));
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: fallback,
      playBytes: (_) async => playCalled = true,
    );
    await engine.speak('안녕하세요');
    expect(playCalled, isFalse);
    expect(fallback.spoken, ['안녕하세요']);
  });

  test('네트워크 예외가 나도 폴백으로 전환된다', () async {
    final fallback = _FakeTtsEngine();
    final client = MockClient((_) async => throw Exception('network down'));
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: client,
      fallback: fallback,
      playBytes: (_) async {},
    );
    await engine.speak('안녕');
    expect(fallback.spoken, ['안녕']);
  });

  test('stopSpeaking은 폴백의 stopSpeaking도 호출한다', () async {
    final fallback = _FakeTtsEngine();
    final engine = CloudTtsEngine(
      voicePreset: preset,
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((_) async => http.Response('', 200)),
      fallback: fallback,
    );
    await engine.stopSpeaking();
    expect(fallback.stopped, isTrue);
  });
}
