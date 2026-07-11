/// 통화 세션 상태머신 (IA §7): connecting → ringing → active → silence_warning
/// → last_30s → ended. 스파이크 A 루프(PTT→STT→LLM 스트리밍→문장 큐 TTS)의 승격판.
///
/// 플랫폼 격리 규칙: 이 파일은 SttEngine/TtsEngine/LlmClient 추상만 사용한다.
///
/// 인내심 게이지는 로컬 휴리스틱(침묵 시 감소)이다 — 실시간 LLM 인크리멘탈
/// 심판(FSD §4)은 P1/vLLM 몫. 클리어 조건 판정도 종료 후 최종 심판이 수행.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../platform/stt_engine.dart';
import '../../platform/tts_engine.dart';
import '../../services/llm_client.dart';
import '../models/boss.dart';

enum CallPhase { connecting, ringing, active, silenceWarning, last30s, ended }

enum CallEndReason { hangUp, timeOut, silenceOverflow }

/// 발화 기록 — 규칙 #3: tStartMs = 통화 시작(active 진입) 기준 상대 시각.
class Utterance {
  const Utterance({required this.speaker, required this.text, required this.tStartMs});
  final String speaker; // 'user' | 'boss'
  final String text;
  final int tStartMs;
}

/// 이벤트 팝업용 (IA §6 인벤토리 #4 — 2초 오버레이).
class CallEvent {
  const CallEvent(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class CallSessionController extends ChangeNotifier {
  CallSessionController({
    required this.boss,
    required this.stt,
    required this.tts,
    required this.llm,
    required this.generateVariables,
  });

  final Boss boss;
  final SttEngine stt;
  final TtsEngine tts;
  final LlmClient llm;
  final Future<List<String>> Function() generateVariables;

  final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // ---- 튜닝 상수 ----
  static const _silenceAfter = Duration(seconds: 6); // 내 차례에 이만큼 조용하면 경고
  static const _patienceDrainPerTick = 0.02; // 침묵 중 0.5초마다 -2%
  static const _tickInterval = Duration(milliseconds: 500);
  static final _sentenceEnd = RegExp(r'[.!?。！？…\n]');

  // ---- 상태 ----
  CallPhase _prePhase = CallPhase.connecting; // active 이전 단계 표시용
  bool _started = false; // active 진입 여부
  bool _ended = false;
  CallEndReason? endReason;

  bool sttAvailable = false;
  bool listening = false; // PTT 누름
  String interim = '';
  bool _replying = false; // LLM 스트림 수신 중
  bool _speaking = false; // TTS 큐 재생 중
  double patience = 1.0;
  DateTime? _startedAt; // active 진입 시각 (tStartMs 기준점)
  DateTime? _idleSince; // 내 차례 시작 시각 (침묵 측정)
  bool _silence = false;
  bool _last30Fired = false;

  final List<Utterance> transcript = [];
  List<String> variables = const [];

  Timer? _ticker;
  StreamSubscription<SttResult>? _sttSub;
  DateTime? _pttPressedAt;
  bool _awaitingFinal = false;
  String _pendingTts = '';
  final List<String> _ttsQueue = [];
  String _systemPrompt = '';

  final _events = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get events => _events.stream;

  // ---- 파생 상태 ----
  CallPhase get phase {
    if (_ended) return CallPhase.ended;
    if (!_started) return _prePhase;
    if (remainingSeconds <= 30) return CallPhase.last30s;
    if (_silence) return CallPhase.silenceWarning;
    return CallPhase.active;
  }

  bool get busy => _replying; // PTT 잠금 (응답 생성 중)
  int get elapsedMs => _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inMilliseconds;
  int get elapsedSeconds => elapsedMs ~/ 1000;
  int get remainingSeconds => boss.timeLimit.inSeconds - elapsedSeconds;

  // ================================================================ lifecycle
  Future<void> start() async {
    _prePhase = CallPhase.connecting;
    notifyListeners();
    sttAvailable = await stt.initialize();
    _sttSub = stt.results.listen(_onSttResult);

    _prePhase = CallPhase.ringing; // 신호음 동안 변수 생성 (지연 흡수)
    notifyListeners();
    try {
      variables = await generateVariables();
    } catch (_) {
      variables = const []; // 변수 없이 진행 (데모 보험)
    }
    if (_ended) return;
    _systemPrompt = boss.buildSystemPrompt(variables);

    // 보스가 먼저 받는다 (2.3 플로우: 신호음 → 보스 응대).
    await _bossReply(seedUser: '(따르릉— 전화가 연결되었다. 네가 전화를 받는다.)');
  }

  void hangUp() => _end(CallEndReason.hangUp);

  void _end(CallEndReason reason) {
    if (_ended) return;
    _ended = true;
    endReason = reason;
    _ticker?.cancel();
    _ttsQueue.clear();
    stt.stop();
    tts.stopSpeaking();
    notifyListeners();
  }

  // ================================================================ PTT
  Future<void> pressTalk() async {
    if (!sttAvailable || _replying || _ended || !_started) return;
    if (_speaking) {
      _ttsQueue.clear(); // 보스 말 끊고 들어가기
      await tts.stopSpeaking();
    }
    _idleSince = null;
    _silence = false;
    listening = true;
    interim = '';
    _pttPressedAt = DateTime.now();
    _awaitingFinal = false;
    notifyListeners();
    await stt.start();
  }

  Future<void> releaseTalk() async {
    if (!listening) return;
    listening = false;
    _awaitingFinal = true;
    _idleSince = DateTime.now(); // final 미도착 대비 — 내 차례는 계속 열려 있다
    notifyListeners();
    await stt.stop();
  }

  /// STT 불가 시 텍스트 입력 폴백 (UI 규칙).
  void sendText(String text) {
    if (_replying || _ended || !_started || text.trim().isEmpty) return;
    _pttPressedAt = DateTime.now();
    _sendUser(text.trim());
  }

  void _onSttResult(SttResult r) {
    if (_ended) return;
    if (r.isFinal) {
      interim = '';
      if (_awaitingFinal) {
        _awaitingFinal = false;
        final text = r.text.trim();
        if (text.isEmpty) {
          _idleSince = DateTime.now(); // 빈 인식 → 다시 내 차례
          notifyListeners();
        } else {
          _sendUser(text);
        }
      }
    } else {
      interim = r.text;
      notifyListeners();
    }
  }

  // ================================================================ 대화 루프
  Future<void> _sendUser(String text) async {
    final t = _pttPressedAt ?? DateTime.now();
    transcript.add(Utterance(
      speaker: 'user',
      text: text,
      tStartMs: _startedAt == null ? 0 : t.difference(_startedAt!).inMilliseconds,
    ));
    notifyListeners();
    await _bossReply();
  }

  Future<void> _bossReply({String? seedUser}) async {
    _replying = true;
    _pendingTts = '';
    notifyListeners();

    final tStart = elapsedMs;
    var bossText = '';
    transcript.add(Utterance(speaker: 'boss', text: '', tStartMs: tStart));
    try {
      await for (final delta in llm.chatStream(_buildMessages(seedUser))) {
        if (_ended) return;
        bossText += delta;
        transcript[transcript.length - 1] =
            Utterance(speaker: 'boss', text: bossText, tStartMs: tStart);
        _feedTts(delta);
        notifyListeners();
      }
      final rest = _pendingTts.trim();
      _pendingTts = '';
      if (rest.isNotEmpty) _enqueueTts(rest);
      if (bossText.isEmpty) transcript.removeLast();
    } catch (_) {
      if (bossText.isEmpty) transcript.removeLast(); // 부분 응답은 기록 유지
      _events.add(const CallEvent('연결이 불안정해요', '응답을 받지 못했어요. 다시 말해 보세요.'));
      _idleSince = DateTime.now();
    } finally {
      _replying = false;
      notifyListeners();
    }
  }

  /// 히스토리 최근 8발화 유지 (개발 규약 6~8턴).
  List<LlmMessage> _buildMessages(String? seedUser) {
    final spoken = transcript.where((u) => u.text.isNotEmpty).toList();
    final recent = spoken.length > 8 ? spoken.sublist(spoken.length - 8) : spoken;
    return [
      LlmMessage(role: 'system', content: _systemPrompt),
      if (seedUser != null) LlmMessage(role: 'user', content: seedUser),
      for (final u in recent)
        LlmMessage(role: u.speaker == 'user' ? 'user' : 'assistant', content: u.text),
    ];
  }

  // ================================================================ TTS 큐
  void _feedTts(String delta) {
    _pendingTts += delta;
    while (true) {
      final m = _sentenceEnd.firstMatch(_pendingTts);
      if (m == null) break;
      final sentence = _pendingTts.substring(0, m.end).trim();
      _pendingTts = _pendingTts.substring(m.end);
      if (sentence.isNotEmpty) _enqueueTts(sentence);
    }
  }

  Future<void> _enqueueTts(String sentence) async {
    _ttsQueue.add(sentence);
    if (_speaking) return;
    _speaking = true;
    if (!_started) _activate(); // 첫 발성 = 통화 시작 (active)
    notifyListeners();
    while (_ttsQueue.isNotEmpty && !_ended) {
      await tts.speak(_ttsQueue.removeAt(0));
    }
    _speaking = false;
    if (!_replying && !_ended) _idleSince = DateTime.now(); // 이제 내 차례
    notifyListeners();
  }

  // ================================================================ ticker
  void _activate() {
    _started = true;
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    if (_ended) return;
    // 침묵 감지: 내 차례(_idleSince)가 열려 있고 PTT/보스 발화가 없을 때만.
    if (_idleSince != null && !listening && !_speaking && !_replying) {
      final quiet = DateTime.now().difference(_idleSince!);
      if (quiet >= _silenceAfter) {
        if (!_silence) {
          _silence = true;
          _events.add(const CallEvent('침묵 경고', '보스 인내심이 떨어지고 있어요'));
        }
        patience = (patience - _patienceDrainPerTick).clamp(0.0, 1.0);
        if (patience <= 0) {
          _end(CallEndReason.silenceOverflow);
          return;
        }
      }
    } else if (_silence) {
      _silence = false;
    }
    if (remainingSeconds <= 30 && !_last30Fired) {
      _last30Fired = true;
      _events.add(const CallEvent('남은 시간 30초', '용건을 마무리하세요'));
    }
    if (remainingSeconds <= 0) {
      _end(CallEndReason.timeOut);
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sttSub?.cancel();
    _events.close();
    tts.stopSpeaking();
    super.dispose();
  }
}
