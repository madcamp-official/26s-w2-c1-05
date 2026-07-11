import '../models/boss.dart';
import 'call_session.dart';
import 'llm_tasks.dart';

/// 종료된 판의 기록. 결과 화면이 sessionId로 조회한다.
class CallRecord {
  CallRecord({
    required this.boss,
    required this.transcript,
    required this.endReason,
    required this.elapsedMs,
    this.serverSessionId,
  });

  final Boss boss;
  final List<Utterance> transcript;
  final CallEndReason endReason;
  final int elapsedMs;

  /// 서버 sessions.id — null이면 종료 보고 스킵 (오프라인/시작 보고 실패).
  final String? serverSessionId;

  /// 최종 심판은 1회만 실행 — 결과 화면 재진입/탭 전환에도 재호출 없음.
  Future<JudgeResult>? judgeFuture;

  /// 종료 보고(POST /sessions/{id}/end)는 1회만 — 재심판 시 트랜스크립트
  /// 중복 INSERT 방지.
  bool endReported = false;
}

/// 인메모리 세션 스토어 (DB는 P1.5 전적에서). 프로세스 생명주기 동안만 유지.
class SessionStore {
  SessionStore._();

  static final Map<String, CallRecord> _records = {};

  static void put(String sessionId, CallRecord record) => _records[sessionId] = record;

  static CallRecord? get(String sessionId) => _records[sessionId];
}
