import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/boss.dart';
import '../../services/game_server_client.dart';
import '../tts_engine.dart';
import 'flutter_tts_engine.dart';

/// 서버 `/tts/synthesize`(Google Cloud TTS 프록시) 기반 TTS 엔진.
/// 오디오는 임시 파일로 받아 [AudioPlayer]로 재생한다(just_audio의 experimental
/// StreamAudioSource 대신 안정적인 setFilePath 사용). 서버 실패(키 미설정 503,
/// 네트워크 오류 등) 시 [fallback]으로 자동 전환 — 통화가 TTS 실패로 끊기면
/// 안 되므로. [httpClient]/[fallback]/[playBytes]는 테스트 주입용(기본값은 실제
/// 구현).
class CloudTtsEngine implements TtsEngine {
  CloudTtsEngine({
    required this.voicePreset,
    String? baseUrl,
    http.Client? httpClient,
    TtsEngine? fallback,
    Future<void> Function(Uint8List bytes)? playBytes,
  })  : baseUrl = baseUrl ?? gameServerUrl,
        _httpClient = httpClient ?? http.Client(),
        _fallback = fallback ?? FlutterTtsEngine() {
    _playBytes = playBytes ?? _defaultPlayBytes;
  }

  final TtsVoicePreset voicePreset;
  final String baseUrl;
  final http.Client _httpClient;
  final TtsEngine _fallback;
  final AudioPlayer _player = AudioPlayer();
  late final Future<void> Function(Uint8List bytes) _playBytes;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<void> speak(String text, {double pitch = 1.0, double rate = 0.5}) async {
    if (text.trim().isEmpty) return;
    try {
      final bytes = await _synthesize(text);
      await _playBytes(bytes);
    } catch (_) {
      // 서버 미가용·네트워크 오류 등 — 통화 지속을 위해 OS 내장 TTS로 폴백.
      await _fallback.speak(text, pitch: pitch, rate: rate);
    }
  }

  Future<Uint8List> _synthesize(String text) async {
    final request = http.Request('POST', Uri.parse('$baseUrl/tts/synthesize'))
      ..headers['Content-Type'] = 'application/json'
      // 한글 포함 → UTF-8 바이트로 명시 인코딩 (인코딩 모호성 제거).
      ..bodyBytes = utf8.encode(jsonEncode({
        'text': text,
        'voice_name': voicePreset.voiceName,
        'pace': voicePreset.pace,
        if (voicePreset.pitch != null) 'pitch': voicePreset.pitch,
      }));
    final response = await http.Response.fromStream(
        await _httpClient.send(request).timeout(_timeout));
    if (response.statusCode != 200) {
      throw Exception('TTS synthesize ${response.statusCode}: ${response.body}');
    }
    return response.bodyBytes;
  }

  Future<void> _defaultPlayBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    // 서버 백엔드에 따라 WAV(Qwen)·MP3(Google)가 오므로 매직 바이트로 판별.
    final isWav = bytes.length > 4 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46; // 'RIFF'
    final ext = isWav ? 'wav' : 'mp3';
    final file = File('${dir.path}/tts_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes);
    try {
      await _player.setFilePath(file.path);
      await _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  @override
  Future<void> stopSpeaking() async {
    await _player.stop();
    await _fallback.stopSpeaking();
  }
}
