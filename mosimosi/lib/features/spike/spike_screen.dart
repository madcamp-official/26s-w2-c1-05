import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/stt_engine.dart';
import '../../platform/stt_factory.dart';
import '../../platform/tts_engine.dart';
import '../../platform/tts_factory.dart';
import '../../services/llm_client.dart';
import '../../services/llm_factory.dart';

/// Day 1 스파이크 (FSD §5): push-to-talk → STT → LLM 스트리밍 → 문장 큐 TTS.
/// 버튼 뗀 시점 → 첫 TTS 발성 시점 지연(ms)을 측정해 표시. 성공 기준 ≤1.5s.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

const _systemPrompt =
    '너는 치과 접수원이야. 반드시 1~2문장의 짧은 한국어 구어체로만 응답해.';

class _Turn {
  _Turn(this.speaker, this.text);
  final String speaker; // '나' | '접수원'
  String text;
}

class _SpikeScreenState extends State<SpikeScreen> {
  late final SttEngine _stt;
  late final TtsEngine _tts;
  late final LlmClient _llm;
  StreamSubscription<SttResult>? _sttSub;

  bool _sttAvailable = false;
  bool _listening = false;
  bool _thinking = false;
  bool _awaitingFinal = false;

  String _interim = '';
  int? _latencyMs;
  final List<_Turn> _turns = [];
  final _fallbackController = TextEditingController();

  // 스트리밍 → 문장 분해 → TTS 큐
  final RegExp _sentenceEnd = RegExp(r'[.!?。！？…\n]');
  String _pending = '';
  final List<String> _ttsQueue = [];
  bool _ttsBusy = false;
  DateTime? _releaseAt; // 버튼 뗀 시각
  DateTime? _firstTtsAt; // 이번 턴 첫 발성 시각

  @override
  void initState() {
    super.initState();
    _tts = createTtsEngine();
    _llm = createLlmClient(); // 프록시 경유 (규칙 #4) — 보스 대화는 vLLM으로
    _stt = createSttEngine();
    _sttSub = _stt.results.listen(_onSttResult);
    _initStt();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize();
    if (mounted) setState(() => _sttAvailable = ok);
  }

  void _onSttResult(SttResult r) {
    if (r.isFinal) {
      setState(() => _interim = '');
      if (_awaitingFinal) {
        _awaitingFinal = false;
        final text = r.text.trim();
        if (text.isNotEmpty) _sendToLlm(text);
      }
    } else {
      setState(() => _interim = r.text);
    }
  }

  Future<void> _onPressStart() async {
    if (!_sttAvailable || _thinking) return;
    setState(() {
      _interim = '';
      _latencyMs = null;
      _listening = true;
    });
    _awaitingFinal = false;
    await _stt.start();
  }

  Future<void> _onPressEnd() async {
    if (!_listening) return;
    setState(() => _listening = false);
    _releaseAt = DateTime.now();
    _awaitingFinal = true;
    await _stt.stop();
  }

  Future<void> _sendToLlm(String userText) async {
    setState(() {
      _turns.add(_Turn('나', userText));
      _turns.add(_Turn('접수원', ''));
      _thinking = true;
      _pending = '';
      _firstTtsAt = null;
    });
    final reply = _turns.last;

    final history = _buildMessages();
    try {
      await for (final delta in _llm.chatStream(history)) {
        reply.text += delta;
        _feedTts(delta);
        setState(() {});
      }
    } catch (e) {
      reply.text = '[오류] $e';
    }
    // 남은 버퍼(문장부호 없이 끝난 경우) 마저 재생
    final rest = _pending.trim();
    _pending = '';
    if (rest.isNotEmpty) _enqueueTts(rest);

    if (mounted) setState(() => _thinking = false);
  }

  /// 최근 8개 메시지(약 4턴)만 유지 — CLAUDE.md 히스토리 규약.
  /// 방금 추가한 빈 '접수원' 턴은 text가 비어 자동 제외, 최신 유저 발화는 포함됨.
  List<LlmMessage> _buildMessages() {
    final completed = _turns.where((t) => t.text.trim().isNotEmpty).toList();
    final recent =
        completed.length > 8 ? completed.sublist(completed.length - 8) : completed;
    return [
      const LlmMessage(role: 'system', content: _systemPrompt),
      for (final t in recent)
        LlmMessage(
          role: t.speaker == '나' ? 'user' : 'assistant',
          content: t.text,
        ),
    ];
  }

  /// 스트림 delta를 누적해 완성된 문장 단위로 TTS 큐에 투입.
  void _feedTts(String delta) {
    _pending += delta;
    while (true) {
      final m = _sentenceEnd.firstMatch(_pending);
      if (m == null) break;
      final sentence = _pending.substring(0, m.end).trim();
      _pending = _pending.substring(m.end);
      if (sentence.isNotEmpty) _enqueueTts(sentence);
    }
  }

  Future<void> _enqueueTts(String sentence) async {
    _ttsQueue.add(sentence);
    if (_ttsBusy) return;
    _ttsBusy = true;
    while (_ttsQueue.isNotEmpty) {
      final s = _ttsQueue.removeAt(0);
      if (_firstTtsAt == null && _releaseAt != null) {
        _firstTtsAt = DateTime.now();
        setState(() =>
            _latencyMs = _firstTtsAt!.difference(_releaseAt!).inMilliseconds);
      }
      await _tts.speak(s);
    }
    _ttsBusy = false;
  }

  void _sendFallback() {
    final text = _fallbackController.text.trim();
    if (text.isEmpty || _thinking) return;
    _fallbackController.clear();
    _releaseAt = DateTime.now(); // 폴백도 지연 측정 기준점
    _sendToLlm(text);
  }

  @override
  void dispose() {
    _sttSub?.cancel();
    _tts.stopSpeaking();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Day 1 스파이크 · 치과 접수원')),
      body: Column(
        children: [
          _latencyBanner(),
          Expanded(child: _transcript()),
          if (_interim.isNotEmpty || _listening) _interimBar(),
          const Divider(height: 1),
          _controls(),
        ],
      ),
    );
  }

  Widget _latencyBanner() {
    final ok = _latencyMs != null && _latencyMs! <= 1500;
    return Container(
      width: double.infinity,
      color: _latencyMs == null
          ? Colors.grey.shade200
          : (ok ? Colors.green.shade100 : Colors.red.shade100),
      padding: const EdgeInsets.all(12),
      child: Text(
        _latencyMs == null
            ? '지연: — (버튼 뗀 시점 → 첫 발성)'
            : '지연: ${_latencyMs}ms  ${ok ? '✓ ≤1.5s' : '✗ >1.5s'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _transcript() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _turns.length,
      itemBuilder: (context, i) {
        final t = _turns[i];
        final mine = t.speaker == '나';
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mine ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(t.text.isEmpty ? '…' : t.text),
          ),
        );
      },
    );
  }

  Widget _interimBar() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.all(12),
      child: Text(_interim.isEmpty ? '(듣는 중…)' : _interim,
          style: TextStyle(color: Colors.grey.shade700)),
    );
  }

  Widget _controls() {
    if (!_sttAvailable) {
      // isAvailable == false → 텍스트 입력 폴백 (IA/Instructions 규칙)
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fallbackController,
                decoration: const InputDecoration(
                  hintText: 'STT 불가 — 텍스트 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendFallback(),
              ),
            ),
            IconButton(onPressed: _sendFallback, icon: const Icon(Icons.send)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTapDown: (_) => _onPressStart(),
        onTapUp: (_) => _onPressEnd(),
        onTapCancel: _onPressEnd,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: _listening ? Colors.red : Colors.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            _thinking
                ? '응답 생성 중…'
                : (_listening ? '듣는 중 — 떼면 전송' : '눌러서 말하기 (Push-to-talk)'),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
