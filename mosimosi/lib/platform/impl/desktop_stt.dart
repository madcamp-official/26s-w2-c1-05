import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../audio_recorder.dart';
import '../stt_engine.dart';

/// 데스크톱 STT: `record`로 마이크 PCM16 캡처 → WebSocket으로 서버 faster-whisper
/// 전송 → 반환 텍스트를 [results] 스트림으로 방출(스파이크 A 화면 재사용).
/// 서버 미연결 시 [isAvailable] == false → 화면이 텍스트 입력 폴백 표시.
class DesktopSttEngine implements SttEngine {
  DesktopSttEngine({required this.whisperUrl, required this.recorder});

  final String whisperUrl;
  final AudioRecorder recorder;

  final StreamController<SttResult> _controller =
      StreamController<SttResult>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<List<int>>? _audioSub;
  bool _available = false;
  DateTime? _startedAt; // 세션(통화) 시작 시각 — tStartMs 기준점

  @override
  Stream<SttResult> get results => _controller.stream;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> initialize() async {
    if (whisperUrl.isEmpty) return _available = false;
    // 서버 도달 가능 여부만 확인(throwaway 연결) → 실제 스트림은 start()에서.
    try {
      final probe = WebSocketChannel.connect(Uri.parse(whisperUrl));
      await probe.ready.timeout(const Duration(seconds: 3));
      await probe.sink.close();
      return _available = true;
    } catch (_) {
      return _available = false;
    }
  }

  @override
  Future<void> start() async {
    if (!_available) return;
    _startedAt ??= DateTime.now();
    await _ensureChannel();

    final chunks = recorder.startChunks();
    _audioSub = chunks.listen(
      (bytes) => _channel?.sink.add(bytes),
      onError: (_) {}, // 캡처 실패는 무시(폴백은 서버 연결 기준)
      cancelOnError: false,
    );
  }

  @override
  Future<void> stop() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await recorder.stop();
    // 현재 버퍼를 즉시 최종 분절로 flush 요청(0.8초 무음 대기 없이).
    _channel?.sink.add(jsonEncode({'event': 'stop'}));
  }

  /// 세션 동안 지속되는 단일 WebSocket. 서버 텍스트 결과를 results로 중계.
  Future<void> _ensureChannel() async {
    if (_channel != null) return;
    final channel = WebSocketChannel.connect(Uri.parse(whisperUrl));
    await channel.ready;
    _channel = channel;
    channel.stream.listen(
      _onServerMessage,
      onError: (_) {},
      onDone: () => _channel = null,
      cancelOnError: false,
    );
  }

  void _onServerMessage(dynamic message) {
    if (_controller.isClosed) return;
    final data = jsonDecode(message as String) as Map<String, dynamic>;
    _controller.add(SttResult(
      text: (data['text'] as String?) ?? '',
      isFinal: (data['isFinal'] as bool?) ?? true,
      tStartMs: (data['tStartMs'] as int?) ??
          DateTime.now()
              .difference(_startedAt ?? DateTime.now())
              .inMilliseconds,
    ));
  }
}
