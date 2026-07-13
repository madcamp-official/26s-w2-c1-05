import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../audio_recorder.dart';
import '../stt_engine.dart';

/// 공용 STT: `record`로 마이크 PCM16 캡처 → WebSocket으로 서버 faster-whisper
/// 전송 → 반환 텍스트를 [results] 스트림으로 방출. 데스크톱·Android 공통 구현체
/// (record 패키지가 두 플랫폼 다 지원 — 온디바이스 STT 파편화를 없애기 위해 통일).
/// [start] 1회 호출 후 계속 스트리밍하면, 서버 VAD(webrtcvad, 0.8초 침묵)가
/// 알아서 발화 단위로 끊어 여러 건의 isFinal 결과를 순차로 내려준다 —
/// 오픈마이크(상시 리스닝)는 클라 쪽에 별도 침묵판정 없이 이 특성만으로 구현됨.
/// 서버 미연결 시 [isAvailable] == false → 화면이 텍스트 입력 폴백 표시.
class WhisperSttEngine implements SttEngine {
  WhisperSttEngine({required this.whisperUrl, required this.recorder});

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
    // 마이크 권한 먼저 확인 — 미허용이면 OS가 요청 다이얼로그를 띄운다.
    // (예전 Android 네이티브 STT는 이 요청을 자체적으로 했지만, whisper 스트리밍
    // 방식은 record 패키지를 직접 쓰므로 여기서 명시적으로 확인해야 한다.)
    if (!await recorder.hasPermission()) return _available = false;
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

  int _chunkCount = 0; // 진단용 — 얼마나 자주 로그를 남길지 조절

  @override
  Future<void> start() async {
    if (!_available) {
      debugPrint('[WhisperSttEngine] start() 무시됨 — _available=false');
      return;
    }
    debugPrint('[WhisperSttEngine] start() 호출');
    _startedAt ??= DateTime.now();
    try {
      await _ensureChannel();
    } catch (e) {
      debugPrint('[WhisperSttEngine] WS 채널 연결 실패: $e');
      return;
    }

    _chunkCount = 0;
    final chunks = recorder.startChunks();
    _audioSub = chunks.listen(
      (bytes) {
        _chunkCount++;
        if (_chunkCount == 1 || _chunkCount % 50 == 0) {
          debugPrint('[WhisperSttEngine] 오디오 청크 #$_chunkCount (${bytes.length} bytes) 전송');
        }
        _channel?.sink.add(bytes);
      },
      // 캡처 실패(권한 회수·하드웨어 오류 등)를 조용히 삼키면 원인 파악이 불가능해지므로
      // 최소한 로그는 남긴다. UI 폴백은 initialize()의 사전 권한 체크로 대부분 방지됨.
      onError: (Object e) => debugPrint('[WhisperSttEngine] 오디오 캡처 오류: $e'),
      onDone: () => debugPrint('[WhisperSttEngine] 오디오 청크 스트림 종료(onDone)'),
      cancelOnError: false,
    );
  }

  @override
  Future<void> stop() async {
    debugPrint('[WhisperSttEngine] stop() 호출 (누적 청크 $_chunkCount개)');
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
    debugPrint('[WhisperSttEngine] WS 채널 연결됨: $whisperUrl');
    channel.stream.listen(
      _onServerMessage,
      onError: (Object e) => debugPrint('[WhisperSttEngine] WS 수신 오류: $e'),
      onDone: () {
        debugPrint('[WhisperSttEngine] WS 채널 종료됨(onDone)');
        _channel = null;
      },
      cancelOnError: false,
    );
  }

  void _onServerMessage(dynamic message) {
    debugPrint('[WhisperSttEngine] 서버 메시지 수신: $message');
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
