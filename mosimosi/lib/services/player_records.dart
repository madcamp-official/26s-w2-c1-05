import 'package:flutter/foundation.dart';

import '../core/local_store.dart';
import 'game_server_client.dart';

/// 서버 기록 변경 신호 — 판 종료 보고 성공 시 bump.
/// 홈/도감/전적은 셸 indexedStack이라 탭 복귀 시 initState가 다시 안 돌므로,
/// 이 notifier를 listen해 재조회한다.
final ValueNotifier<int> recordsVersion = ValueNotifier(0);

void bumpRecordsVersion() => recordsVersion.value++;

/// 서버 기록 조회 공용 모델·함수 — 홈/도감/전적 3화면 공유 (Phase 2 §5).
/// 계약 실측: GET /users/{id}/progress → [{boss_id, cleared_at, best_score,
/// attempts}], GET /users/{id}/sessions → [{id, mode, boss_id, room_id,
/// started_at(UTC ISO), ended_at, result, score}].

class BossProgress {
  const BossProgress({
    required this.bossId,
    required this.cleared,
    required this.bestScore,
    required this.attempts,
  });

  final String bossId;
  final bool cleared;
  final int? bestScore;
  final int attempts;

  factory BossProgress.fromJson(Map<String, dynamic> j) => BossProgress(
        bossId: j['boss_id'] as String,
        cleared: j['cleared_at'] != null,
        bestScore: (j['best_score'] as num?)?.round(),
        attempts: (j['attempts'] as num?)?.round() ?? 0,
      );
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.mode,
    required this.bossId,
    required this.startedAt,
    required this.result,
    required this.score,
  });

  final String id;
  final String mode; // 'boss' | 'battle'
  final String? bossId;
  final DateTime startedAt; // 로컬 시간 (서버는 UTC → toLocal 변환됨)
  final String? result; // 'win' | 'lose' | 'abort' | null(미종료)
  final int? score;

  bool get win => result == 'win';

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        mode: j['mode'] as String,
        bossId: j['boss_id'] as String?,
        startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
        result: j['result'] as String?,
        score: (j['score'] as num?)?.round(),
      );
}

/// 도감 진행. 계정 없으면 빈 맵 (온보딩 전 — 게이팅상 도달 안 하지만 방어).
Future<Map<String, BossProgress>> fetchProgress() async {
  if (!LocalStore.instance.hasUser) return const {};
  final rows = await GameServerClient().getJsonList('/users/me/progress');
  return {
    for (final r in rows.whereType<Map<String, dynamic>>())
      r['boss_id'] as String: BossProgress.fromJson(r),
  };
}

/// 최근 세션 목록 (최신순 — 서버 ORDER BY started_at DESC).
Future<List<SessionRecord>> fetchSessions({int limit = 50}) async {
  if (!LocalStore.instance.hasUser) return const [];
  final rows =
      await GameServerClient().getJsonList('/users/me/sessions?limit=$limit');
  return [
    for (final r in rows.whereType<Map<String, dynamic>>())
      SessionRecord.fromJson(r),
  ];
}
