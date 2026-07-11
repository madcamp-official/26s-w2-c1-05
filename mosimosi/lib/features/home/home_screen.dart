import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/bosses.dart';
import '../../core/local_store.dart';
import '../../core/models/boss.dart';
import '../../services/player_records.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 1. 홈 (게임 로비) — 디자인 D 섹션 이식.
/// 모바일: 세로 플로우 (헤더+인사 → 모드 카드 2 → 이어서 도전 → 오늘의 기록).
/// 데스크톱: 네이티브 와이드 — 모드 카드 2 + 우측 활동 컬럼.
/// 닉네임·격파·이어서 도전·오늘 기록·최근 통화는 서버 실데이터 (Phase 2 §5).
/// 로딩/연결 실패 시 수치는 '–' 표시.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// null = 로딩 중/연결 실패.
  Map<String, BossProgress>? _progress;
  List<SessionRecord>? _sessions;

  String get _nickname => LocalStore.instance.nickname ?? '민준';

  @override
  void initState() {
    super.initState();
    _load();
    recordsVersion.addListener(_load); // 판 종료 보고 후 재조회 (셸 탭 유지 대응)
  }

  @override
  void dispose() {
    recordsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    // 각각 독립 best-effort — 한쪽 실패가 다른 쪽을 막지 않게.
    fetchProgress().then((p) {
      if (mounted) setState(() => _progress = p);
    }).catchError((_) {});
    fetchSessions(limit: 100).then((s) {
      if (mounted) setState(() => _sessions = s);
    }).catchError((_) {});
  }

  // ---- 파생 값 ----
  int get _clearedCount =>
      bossesSeed.where((b) => _progress?[b.id]?.cleared ?? false).length;

  /// 다음 도전 보스 — 미격파 첫 보스, 올 클리어면 최종 보스(재도전).
  Boss get _nextBoss => bossesSeed.firstWhere(
      (b) => !(_progress?[b.id]?.cleared ?? false),
      orElse: () => bossesSeed.last);

  bool get _allCleared =>
      _progress != null && bossesSeed.every((b) => _progress![b.id]?.cleared ?? false);

  String get _nextBossCaption {
    final progress = _progress;
    if (progress == null) return '…';
    if (_allCleared) return '전 보스 격파! · 재도전';
    final p = progress[_nextBoss.id];
    if (p == null) return '미도전';
    if (p.bestScore != null) return '최고 ${p.bestScore}점 · 미격파';
    return '도전 ${p.attempts}회 · 미격파';
  }

  String get _bossCardStat => _progress == null
      ? '격파 –/8'
      : _allCleared
          ? '격파 $_clearedCount/8 · 올 클리어!'
          : '격파 $_clearedCount/8 · 다음: No.${_nextBoss.number.toString().padLeft(3, '0')}';

  ({int wins, int losses}) get _battleRecord {
    final battles = (_sessions ?? const <SessionRecord>[])
        .where((s) => s.mode == 'battle');
    return (
      wins: battles.where((s) => s.win).length,
      losses: battles.where((s) => s.result == 'lose').length,
    );
  }

  String get _battleStat {
    if (_sessions == null) return '시즌 1 · –';
    final r = _battleRecord;
    return '시즌 1 · ${r.wins}승 ${r.losses}패';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<SessionRecord> get _todaySessions {
    final now = DateTime.now();
    return (_sessions ?? const <SessionRecord>[])
        .where((s) => _isSameDay(s.startedAt, now))
        .toList();
  }

  String get _todayCalls => _sessions == null ? '–' : '${_todaySessions.length}';

  String get _todayWins =>
      _sessions == null ? '–' : '${_todaySessions.where((s) => s.win).length}';

  String get _weekBest {
    final sessions = _sessions;
    if (sessions == null) return '–';
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var best = 0;
    for (final s in sessions) {
      if (s.startedAt.isAfter(cutoff) && (s.score ?? 0) > best) best = s.score!;
    }
    return '$best';
  }

  /// 연속 플레이 일수 — 오늘(또는 어제)부터 거꾸로 이어진 날 수.
  int get _streak {
    final sessions = _sessions;
    if (sessions == null || sessions.isEmpty) return 0;
    final days = {
      for (final s in sessions)
        DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
    };
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1)); // 오늘 아직 안 했으면 어제부터
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isDesktop(context) ? _desktop(context) : _mobile(context),
      ),
    );
  }

  // ================================================================ mobile
  Widget _mobile(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s6, YbsSpace.s5, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('여보세요',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.title, height: 1, color: YbsColor.white)),
                Row(children: [
                  if (_streak > 0) ...[
                    StreakBadge(count: _streak, label: '일 연속'),
                    const SizedBox(width: YbsSpace.s2),
                  ],
                  // 설정 진입 (디자인 데스크톱 헤더의 아바타를 모바일에도 사용)
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: _avatar(size: 36, fontSize: 15),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: _nickname, style: const TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                const TextSpan(text: ' 님, 오늘은 누구한테 걸어볼까요?'),
              ]),
              style: const TextStyle(fontSize: 15, color: YbsColor.textSub),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
            child: _bossModeCardMobile(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
            child: _battleModeCardMobile(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
            child: _continueSection(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, YbsSpace.s5),
            child: _todaySection(),
          ),
        ],
      ),
    );
  }

  Widget _bossModeCardMobile(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/bosses'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5, vertical: 22),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          gradient: RadialGradient(
            center: const Alignment(0.64, -0.64),
            radius: 0.9,
            colors: [YbsColor.live500.withValues(alpha: 0.20), YbsColor.surfaceCard],
          ),
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg),
          boxShadow: YbsShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('보스전',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1.15, color: YbsColor.textHero)),
                Opacity(
                  opacity: 0.85,
                  child: Text('환',
                      style: TextStyle(fontFamily: YbsType.display, fontSize: 36, height: 1, color: YbsColor.live500)),
                ),
              ],
            ),
            const SizedBox(height: YbsSpace.s2),
            const Text('AI 보스에게 전화 걸기 · 도감을 채우세요',
                style: TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
            const SizedBox(height: YbsSpace.s2 + 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('격파 ${_progress == null ? '–' : _clearedCount}/8',
                    style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.live400)),
                const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _battleModeCardMobile(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/battle'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5, vertical: 22),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          gradient: RadialGradient(
            center: const Alignment(0.64, -0.64),
            radius: 0.9,
            colors: [YbsColor.go500.withValues(alpha: 0.16), YbsColor.surfaceCard],
          ),
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg),
          boxShadow: YbsShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('전화 배틀',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1.15, color: YbsColor.textHero)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: YbsColor.go600),
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                  ),
                  child: Text('1V1',
                      style: TextStyle(
                          fontFamily: YbsType.numeric,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: YbsType.labelTracking(11),
                          color: YbsColor.go400)),
                ),
              ],
            ),
            const SizedBox(height: YbsSpace.s2),
            const Text('실시간 사람 대결 · 민원인 vs 상담원',
                style: TextStyle(fontSize: 13, height: 1.5, color: YbsColor.textSub)),
            const SizedBox(height: YbsSpace.s2 + 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_battleStat,
                    style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.go400)),
                const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueSection(BuildContext context) {
    final boss = _nextBoss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_allCleared ? '다시 도전' : '이어서 도전',
            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.textFaint)),
        const SizedBox(height: YbsSpace.s2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s4 - 2),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: YbsColor.surfaceInset,
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.7,
                    colors: [YbsColor.sky400.withValues(alpha: 0.20), Colors.transparent],
                  ),
                  border: Border.all(color: YbsColor.borderSoft),
                  borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
                ),
                alignment: Alignment.center,
                child: Text(boss.portraitSyllable,
                    style: const TextStyle(fontFamily: YbsType.display, fontSize: 19, height: 1, color: YbsColor.sky400)),
              ),
              const SizedBox(width: YbsSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No.${boss.number.toString().padLeft(3, '0')} ${boss.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                    Text(_nextBossCaption, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                  ],
                ),
              ),
              YbsButton(
                  label: '도전',
                  variant: YbsButtonVariant.secondary,
                  size: YbsButtonSize.sm,
                  onTap: () => context.go('/bosses/${boss.id}')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _todaySection() {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s3, vertical: YbsSpace.s4 - 2),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.md),
            ),
            child: Column(
              children: [
                Text(value,
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: 22, fontWeight: FontWeight.w600, height: 1.1, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 기록',
            style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(YbsType.micro) / 2, color: YbsColor.textFaint)),
        const SizedBox(height: YbsSpace.s2),
        Row(children: [
          stat(_todayCalls, '오늘 통화', YbsColor.textHero),
          const SizedBox(width: YbsSpace.s2 + 2),
          stat(_todayWins, '승리', YbsColor.go400),
          const SizedBox(width: YbsSpace.s2 + 2),
          stat(_weekBest, '주간 최고점', YbsColor.gold400),
        ]),
      ],
    );
  }

  // ================================================================ desktop
  Widget _desktop(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('여보세요',
                  style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1, color: YbsColor.white)),
              Row(children: [
                if (_streak > 0) ...[
                  StreakBadge(count: _streak, label: '일 연속'),
                  const SizedBox(width: YbsSpace.s4 - 2),
                ],
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Row(children: [
                    _avatar(size: 36, fontSize: 15),
                    const SizedBox(width: YbsSpace.s2 + 2),
                    Text(_nickname,
                        style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
                  ]),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 28),
          Text('$_nickname 님, 오늘은 누구한테 걸어볼까요?',
              style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.15, color: YbsColor.textHero)),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _bigModeCard(context, boss: true)),
                const SizedBox(width: YbsSpace.s6),
                Expanded(child: _bigModeCard(context, boss: false)),
                const SizedBox(width: YbsSpace.s6),
                SizedBox(width: 420, child: _activityColumn(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigModeCard(BuildContext context, {required bool boss}) {
    final accent = boss ? YbsColor.live500 : YbsColor.go500;
    final r = _battleRecord;
    return GestureDetector(
      onTap: () => boss ? context.go('/bosses') : context.push('/battle'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          gradient: RadialGradient(
            center: const Alignment(0.56, -0.72),
            radius: 0.9,
            colors: [accent.withValues(alpha: boss ? 0.22 : 0.18), YbsColor.surfaceCard],
          ),
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.lg),
          boxShadow: YbsShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (boss)
              Opacity(
                opacity: 0.9,
                child: Text('환',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 52, height: 1, color: accent)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: YbsColor.go600),
                  borderRadius: BorderRadius.circular(YbsRadius.full),
                ),
                child: Text('1V1 · 시즌 1',
                    style: TextStyle(
                        fontFamily: YbsType.numeric,
                        fontSize: YbsType.micro,
                        fontWeight: FontWeight.w600,
                        letterSpacing: YbsType.labelTracking(YbsType.micro),
                        color: YbsColor.go400)),
              ),
            const Spacer(),
            Text(boss ? '보스전' : '전화 배틀',
                style: const TextStyle(fontFamily: YbsType.display, fontSize: 38, height: 1.15, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s3),
            Text(boss ? 'AI 보스에게 전화 걸기.\n전설의 진상 도감을 채우세요.' : '실시간 사람 대결.\n민원인 vs 상담원 — 기세 싸움.',
                style: const TextStyle(fontSize: 15, height: 1.55, color: YbsColor.textSub)),
            const SizedBox(height: YbsSpace.s2 + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      boss
                          ? _bossCardStat
                          : _sessions == null
                              ? '–'
                              : '${r.wins}승 ${r.losses}패',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: YbsType.numeric,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: boss ? YbsColor.live400 : YbsColor.go400)),
                ),
                const SizedBox(width: YbsSpace.s2),
                YbsButton(
                  label: boss ? '도전하기' : '매칭 시작',
                  variant: boss ? YbsButtonVariant.danger : YbsButtonVariant.primary,
                  onTap: () => boss ? context.go('/bosses') : context.push('/battle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityColumn(BuildContext context) {
    Widget resultRow(SessionRecord s) {
      final win = s.win;
      final bossName = s.mode == 'boss'
          ? bossesSeed
              .where((b) => b.id == s.bossId)
              .map((b) => b.name)
              .firstOrNull
          : null;
      final label = s.mode == 'boss' ? '보스전 · ${bossName ?? s.bossId ?? '?'}' : '배틀';
      return Padding(
        padding: const EdgeInsets.only(bottom: YbsSpace.s3),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: win ? YbsColor.gold500 : YbsColor.live600),
              borderRadius: BorderRadius.circular(YbsRadius.xs),
            ),
            child: Text(win ? 'WIN' : 'LOSE',
                style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w700, color: win ? YbsColor.gold400 : YbsColor.live400)),
          ),
          const SizedBox(width: YbsSpace.s2 + 2),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody)),
          ),
          Text(s.score == null ? '—' : '${s.score}',
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, color: win ? YbsColor.gold400 : YbsColor.textFaint)),
        ]),
      );
    }

    final boss = _nextBoss;
    final recent = (_sessions ?? const <SessionRecord>[]).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(YbsSpace.s5),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.lg),
            boxShadow: YbsShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_allCleared ? '다시 도전' : '이어서 도전',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
              const SizedBox(height: YbsSpace.s3),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: YbsColor.surfaceInset,
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.7,
                      colors: [YbsColor.sky400.withValues(alpha: 0.20), Colors.transparent],
                    ),
                    border: Border.all(color: YbsColor.borderSoft),
                    borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(boss.portraitSyllable,
                      style: const TextStyle(fontFamily: YbsType.display, fontSize: 21, height: 1, color: YbsColor.sky400)),
                ),
                const SizedBox(width: YbsSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No.${boss.number.toString().padLeft(3, '0')} ${boss.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                      Text(_nextBossCaption, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                    ],
                  ),
                ),
                YbsButton(
                    label: '도전',
                    variant: YbsButtonVariant.secondary,
                    size: YbsButtonSize.sm,
                    onTap: () => context.go('/bosses/${boss.id}')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: YbsSpace.s5),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(YbsSpace.s5),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.lg),
              boxShadow: YbsShadow.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('최근 통화', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
                const SizedBox(height: YbsSpace.s4 - 2),
                if (_sessions == null)
                  const Text('불러오는 중…', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint))
                else if (recent.isEmpty)
                  const Text('아직 통화 기록이 없어요', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint))
                else
                  for (final s in recent) resultRow(s),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('도감 진행', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
                    Text(_progress == null ? '–/8' : '$_clearedCount/8',
                        style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
                  ],
                ),
                const SizedBox(height: YbsSpace.s2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(YbsRadius.full),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: YbsColor.surfaceInset,
                      border: Border.all(color: YbsColor.borderSoft),
                      borderRadius: BorderRadius.circular(YbsRadius.full),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _clearedCount / 8,
                      child: const ColoredBox(color: YbsColor.live500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar({required double size, required double fontSize}) {
    final syllable = _nickname.isEmpty ? '?' : _nickname.characters.first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: YbsColor.surfaceInset,
        gradient: RadialGradient(
          center: const Alignment(0, -0.24),
          radius: 0.72,
          colors: [YbsColor.go500.withValues(alpha: 0.25), Colors.transparent],
        ),
        border: Border.all(color: YbsColor.go600, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(syllable,
          style: TextStyle(fontFamily: YbsType.display, fontSize: fontSize, height: 1, color: YbsColor.go400)),
    );
  }
}
