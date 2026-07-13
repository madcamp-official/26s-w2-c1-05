import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// 상대 음성(16kHz mono PCM16) 실시간 스트리밍 재생 — 배틀 실통화용.
/// WS로 도착하는 청크를 [feed]로 밀어 넣으면 SoLoud 버퍼 스트림이 이어 재생한다.
/// bufferingTimeNeeds(0.5초)만큼 모이면 자동 시작, 언더런 시 자동 일시정지·재개.
class PcmStreamPlayer {
  AudioSource? _stream;
  static bool _engineReady = false;

  /// 통화 진입 전에 1회 (모든 SoLoud 호출보다 먼저). 실패해도 통화는 진행 —
  /// 재생만 무성(캡션은 살아 있음).
  static Future<void> ensureEngine() async {
    if (_engineReady) return;
    try {
      await SoLoud.instance.init();
      _engineReady = true;
    } catch (e) {
      debugPrint('[PcmStreamPlayer] SoLoud init 실패: $e');
    }
  }

  /// 통화(in_call) 시작 시 호출 — 스트림 생성 + 재생 대기.
  void start() {
    if (!_engineReady || _stream != null) return;
    _stream = SoLoud.instance.setBufferStream(
      maxBufferSizeDuration: const Duration(minutes: 10), // 도달 시 스트림 종료 취급 — 판 제한(5분)보다 넉넉히
      bufferingType: BufferingType.released, // 재생분 즉시 해제 — 실시간 스트림용
      bufferingTimeNeeds: 0.5, // 0.5초 모이면 (재)시작 — 지연 vs 끊김 트레이드오프
      sampleRate: 16000,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    SoLoud.instance.play(_stream!);
  }

  /// 수신 청크 재생 큐에 추가.
  void feed(Uint8List chunk) {
    final stream = _stream;
    if (stream == null) return;
    try {
      SoLoud.instance.addAudioDataStream(stream, chunk);
    } catch (e) {
      // 버퍼 만료·스트림 종료 직후 잔여 청크 등 — 재생 불가 청크는 버린다.
      debugPrint('[PcmStreamPlayer] feed 실패: $e');
    }
  }

  /// 통화 종료·화면 이탈 시. setDataIsEnded는 Windows 행(#426) 리포트가 있어
  /// 쓰지 않고 소스를 바로 폐기한다 (잔여 버퍼 재생 불필요 — 통화가 끝났으므로).
  Future<void> dispose() async {
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      try {
        await SoLoud.instance.disposeSource(stream);
      } catch (_) {}
    }
  }
}
