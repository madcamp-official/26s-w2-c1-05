import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../services/game_server_client.dart';
import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';
import '../shell/main_shell.dart';

/// 3a. 배틀 로비 — 셸 3번째 탭 (홈 · 도감 · 배틀 · 전적).
/// 프로필·전적 카드 + 최근 배틀 + 「매칭 시작」 CTA. 매칭 화면(/battle/matching)의
/// 대기실 역할. 전적은 GET /users/me/battles 실데이터 (미로그인·오프라인은 표기 생략).
class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  Map<String, dynamic>? _data; // GET /users/me/battles 응답
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!LocalStore.instance.hasUser) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await GameServerClient().getJson('/users/me/battles');
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false); // 오프라인 — 통계 생략
    }
  }

  void _startMatching() => context.push('/battle/matching');

  // ---- 파생 값 ----
  int get _wins => (_data?['wins'] as num?)?.toInt() ?? 0;
  int get _losses => (_data?['losses'] as num?)?.toInt() ?? 0;
  int get _streak => (_data?['streak'] as num?)?.toInt() ?? 0;

  String get _seasonLine {
    final total = _wins + _losses;
    final rate = total == 0 ? null : (_wins / total * 100).round();
    return '시즌 1 · $_wins승 $_losses패${rate == null ? '' : ' · 승률 $rate%'}';
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) return _desktop(context);
    return SafeArea(
      child: Column(
        children: [
          const YbsHeader(title: '전화 배틀'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  YbsSpace.s5, 0, YbsSpace.s5, YbsSpace.s3),
              children: [
                _profileCard(),
                const SizedBox(height: YbsSpace.s5),
                _recentSection(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                YbsSpace.s5, YbsSpace.s2, YbsSpace.s5, YbsSpace.s4),
            child: _matchCta(height: 60, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ============================================================== 데스크톱 2컬럼
  Widget _desktop(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 36, 48, 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _heroCard()),
            const SizedBox(width: 24),
            SizedBox(
              width: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileCard(),
                  const SizedBox(height: 24),
                  Expanded(child: SingleChildScrollView(child: _recentSection())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 좌측 히어로 카드 — 모드 소개 + 매칭 시작 (디자인 3a 데스크톱).
  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [
            YbsColor.go500.withValues(alpha: 0.10),
            YbsColor.surfaceCard,
          ],
        ),
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('전화 배틀',
              style: TextStyle(
                  fontFamily: YbsType.display,
                  fontSize: 40,
                  height: 1.15,
                  color: YbsColor.textHero)),
          const SizedBox(height: 18),
          const Text('실시간 1v1 협상 배틀 — 서로의 비밀을 걸고 겨뤄요.\n시나리오와 역할은 매칭마다 무작위예요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, height: 1.55, color: YbsColor.textSub)),
          const SizedBox(height: 24),
          const Column(
            children: [
              Text('03:00',
                  style: TextStyle(
                      fontFamily: YbsType.numeric,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: YbsColor.textHero)),
              SizedBox(height: 2),
              Text('라운드 1개',
                  style:
                      TextStyle(fontSize: 12, color: YbsColor.textFaint)),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(width: 360, child: _matchCta(height: 64, fontSize: 19)),
        ],
      ),
    );
  }

  // ================================================================ 프로필 카드
  Widget _profileCard() {
    final nickname = LocalStore.instance.nickname ?? '나';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [
            YbsColor.go500.withValues(alpha: 0.12),
            YbsColor.surfaceCard,
          ],
        ),
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: YbsColor.surfaceInset,
                  border: Border.all(color: YbsColor.go600, width: 2),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.24),
                    radius: 0.72,
                    colors: [
                      YbsColor.go500.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(nickname.characters.first,
                    style: const TextStyle(
                        fontFamily: YbsType.display,
                        fontSize: 24,
                        height: 1,
                        color: YbsColor.go400)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: YbsColor.textHero)),
                    const SizedBox(height: 2),
                    Text(_loading ? '전적 불러오는 중…' : _seasonLine,
                        style: const TextStyle(
                            fontSize: 12, color: YbsColor.textSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statTile('$_streak', '연승 중',
                  valueColor: _streak > 0 ? YbsColor.go400 : YbsColor.textHero),
              const SizedBox(width: 10),
              _statTile('$_wins', '승', valueColor: YbsColor.go400),
              const SizedBox(width: 10),
              _statTile('$_losses', '패', valueColor: YbsColor.live400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label,
      {Color valueColor = YbsColor.textHero}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: YbsColor.surfaceInset,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontFamily: YbsType.numeric,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: valueColor)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: YbsColor.textSub)),
          ],
        ),
      ),
    );
  }

  // ================================================================ 최근 배틀
  Widget _recentSection() {
    final recent = (_data?['recent'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('최근 배틀',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: YbsColor.textFaint)),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: YbsSpace.s4),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: YbsColor.textFaint))),
          )
        else if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(YbsSpace.s4),
            decoration: BoxDecoration(
              color: YbsColor.surfaceCard,
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('아직 배틀 기록이 없어요 — 첫 매칭을 시작해 보세요!',
                style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
          )
        else
          for (final r in recent.take(5)) ...[
            _recentRow(r as Map<String, dynamic>),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _recentRow(Map<String, dynamic> r) {
    final result = r['result'] as String? ?? 'draw';
    final (label, color, border) = switch (result) {
      'win' => ('WIN', YbsColor.gold400, YbsColor.gold500),
      'lose' => ('LOSE', YbsColor.live400, YbsColor.live600),
      _ => ('DRAW', YbsColor.textSub, YbsColor.borderStrong),
    };
    final my = (r['myMomentum'] as num?)?.round() ?? 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    fontFamily: YbsType.numeric,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('vs ${r['opponent'] ?? '상대'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, color: YbsColor.textBody)),
          ),
          Text('$my:${100 - my}',
              style: TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: 13,
                  color: result == 'win'
                      ? YbsColor.go400
                      : YbsColor.textFaint)),
        ],
      ),
    );
  }

  // ================================================================ CTA
  Widget _matchCta({required double height, required double fontSize}) {
    return GestureDetector(
      onTap: _startMatching,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: YbsColor.go500,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 24)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call, size: 21, color: YbsColor.textOnGo),
            const SizedBox(width: 10),
            Text('매칭 시작',
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: YbsColor.textOnGo)),
          ],
        ),
      ),
    );
  }
}
