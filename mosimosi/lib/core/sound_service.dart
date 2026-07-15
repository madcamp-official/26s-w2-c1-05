import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// 앱 전역 효과음·BGM (flutter_soloud 저지연 엔진 공용).
/// 에셋 5종(bgm·button_click·success·failure·chat)은 로드하고,
/// 전화 신호음(ringback)·끊는 찰칵 소리는 런타임 WAV로 합성해 넣는다.
/// 오디오 실패는 전부 무해하게 삼킨다 — 소리는 게임 진행을 막으면 안 된다.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _assets = [
    'bgm',
    'button_click',
    'success',
    'failure',
    'chat',
  ];

  bool _ready = false;
  final Map<String, AudioSource> _src = {};
  SoundHandle? _bgm;
  SoundHandle? _ring;
  int _bgmSuppress = 0; // 통화·배틀 등 몰입 화면 깊이 (0일 때만 BGM 가청)

  Future<void> init() async {
    if (_ready) return;
    try {
      await SoLoud.instance.init();
      for (final n in _assets) {
        _src[n] = await SoLoud.instance.loadAsset('assets/sounds/$n.mp3');
      }
      _src['ringback'] = await SoLoud.instance.loadMem('ringback', _ringbackWav());
      _src['hangup'] = await SoLoud.instance.loadMem('hangup', _hangupWav());
      _ready = true;
    } catch (e) {
      debugPrint('[SoundService] init 실패: $e');
    }
  }

  Future<void> _play(String name, {double volume = 1}) async {
    if (!_ready) return;
    final s = _src[name];
    if (s == null) return;
    try {
      SoLoud.instance.play(s, volume: volume);
    } catch (_) {}
  }

  // ---- 원샷 효과음 ----
  void click() => _play('button_click', volume: 0.6);
  void success() => _play('success');
  void failure() => _play('failure');
  void chat() => _play('chat', volume: 0.7); // 인트로에서 상대 메시지 도착
  void hangup() => _play('hangup', volume: 0.9);

  // ---- BGM (로비 루프) ----
  Future<void> startBgm() async {
    await init();
    if (_bgm != null) return;
    final s = _src['bgm'];
    if (s == null) return;
    try {
      _bgm = SoLoud.instance.play(s, volume: 0.35, looping: true);
      _applyBgmPause();
    } catch (_) {}
  }

  /// 몰입 화면 진입/이탈 — 깊이 카운터로 BGM 음소거 (전환 중 튐 방지).
  void suppressBgm() {
    _bgmSuppress++;
    _applyBgmPause();
  }

  void unsuppressBgm() {
    if (_bgmSuppress > 0) _bgmSuppress--;
    _applyBgmPause();
  }

  void _applyBgmPause() {
    final h = _bgm;
    if (h == null) return;
    if (_bgmSuppress > 0) {
      try {
        SoLoud.instance.setPause(h, true);
      } catch (_) {}
      return;
    }
    // 재생 복구는 다음 프레임까지 미룬다 — 통화→결과처럼 한 화면이 dispose하며
    // 다른 화면이 같은 프레임에 다시 suppress하는 전환에서 BGM이 튀지 않게.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_bgmSuppress == 0 && _bgm != null) {
        try {
          SoLoud.instance.setPause(_bgm!, false);
        } catch (_) {}
      }
    });
  }

  // ---- 전화 신호음 (ringing 동안 루프) ----
  Future<void> startRingback() async {
    if (!_ready || _ring != null) return;
    final s = _src['ringback'];
    if (s == null) return;
    try {
      _ring = SoLoud.instance.play(s, volume: 0.7, looping: true);
    } catch (_) {}
  }

  void stopRingback() {
    final h = _ring;
    _ring = null;
    if (h == null) return;
    try {
      SoLoud.instance.stop(h);
    } catch (_) {}
  }

  // ================================================================ WAV 합성
  static const _sr = 24000;

  /// 전화 수신음 — 국내 통화 신호음 근사(450Hz+480Hz, 1초 울림 / 2초 쉼, 3초 루프).
  Uint8List _ringbackWav() {
    final n = _sr * 3;
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _sr;
      final phase = t % 3.0;
      if (phase < 1.0) {
        // 1초 울림 구간 — 짧은 페이드로 클릭음 방지
        final env = _edgeFade(phase, 1.0, 0.02);
        final s = math.sin(2 * math.pi * 450 * t) + math.sin(2 * math.pi * 480 * t);
        pcm[i] = (s / 2 * env * 0.9 * 32767).round().clamp(-32768, 32767);
      }
    }
    return _wrapWav(pcm);
  }

  /// 끊는 찰칵 소리 — 짧은 감쇠 노이즈 버스트 2발(수화기 내려놓는 느낌).
  Uint8List _hangupWav() {
    final n = (_sr * 0.18).round();
    final pcm = Int16List(n);
    final rng = math.Random(7);
    void burst(int start, int len, double amp) {
      for (var i = 0; i < len && start + i < n; i++) {
        final env = math.exp(-i / (len * 0.28)); // 빠른 감쇠
        final noise = (rng.nextDouble() * 2 - 1);
        pcm[start + i] =
            ((noise * env * amp) * 32767).round().clamp(-32768, 32767);
      }
    }
    burst(0, (_sr * 0.03).round(), 0.55); // 찰
    burst((_sr * 0.06).round(), (_sr * 0.05).round(), 0.75); // 칵
    return _wrapWav(pcm);
  }

  double _edgeFade(double t, double dur, double fade) {
    if (t < fade) return t / fade;
    if (t > dur - fade) return (dur - t) / fade;
    return 1.0;
  }

  /// PCM16 mono → 44바이트 WAV 헤더 래핑.
  Uint8List _wrapWav(Int16List pcm) {
    final dataBytes = pcm.buffer.asUint8List();
    final b = BytesBuilder();
    void s(String x) => b.add(x.codeUnits);
    void u32(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    s('RIFF');
    u32(36 + dataBytes.length);
    s('WAVE');
    s('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(_sr);
    u32(_sr * 2); // byte rate
    u16(2); // block align
    u16(16); // bits
    s('data');
    u32(dataBytes.length);
    b.add(dataBytes);
    return b.toBytes();
  }
}
