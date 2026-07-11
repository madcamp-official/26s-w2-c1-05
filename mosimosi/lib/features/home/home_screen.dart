import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 1. 홈 (게임 로비) — 디자인 D 섹션 이식.
/// 모바일: 세로 플로우 (헤더+인사 → 모드 카드 2 → 이어서 도전 → 오늘의 기록).
/// 데스크톱: 네이티브 와이드 — 모드 카드 2 + 우측 활동 컬럼.
/// 전적·연승 등 수치는 영속화 전 목 데이터.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _nickname = '민준';

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
                  const StreakBadge(count: 3, label: '일 연속'),
                  const SizedBox(width: YbsSpace.s2),
                  // 설정 진입 (디자인 데스크톱 헤더의 아바타를 모바일에도 사용)
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: _avatar(size: 36, fontSize: 15),
                  ),
                ]),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: _nickname, style: TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                TextSpan(text: ' 님, 오늘은 누구한테 걸어볼까요?'),
              ]),
              style: TextStyle(fontSize: 15, color: YbsColor.textSub),
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
              children: const [
                Text('격파 3/8',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.live400)),
                Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
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
              children: const [
                Text('시즌 1 · 12승 9패',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.go400)),
                Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이어서 도전',
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
                child: const Text('말',
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 19, height: 1, color: YbsColor.sky400)),
              ),
              const SizedBox(width: YbsSpace.s3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No.004 말 끊는 김 과장',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                    Text('최고 71점 · 미격파', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                  ],
                ),
              ),
              // 미구현 보스(No.004) — 도감으로 안내
              YbsButton(label: '재도전', variant: YbsButtonVariant.secondary, size: YbsButtonSize.sm, onTap: () => context.go('/bosses')),
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
          stat('2', '오늘 통화', YbsColor.textHero),
          const SizedBox(width: YbsSpace.s2 + 2),
          stat('1', '승리', YbsColor.go400),
          const SizedBox(width: YbsSpace.s2 + 2),
          stat('87', '주간 최고점', YbsColor.gold400),
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
                const StreakBadge(count: 3, label: '일 연속'),
                const SizedBox(width: YbsSpace.s4 - 2),
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Row(children: [
                    _avatar(size: 36, fontSize: 15),
                    const SizedBox(width: YbsSpace.s2 + 2),
                    const Text(_nickname,
                        style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody)),
                  ]),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 28),
          const Text('$_nickname 님, 오늘은 누구한테 걸어볼까요?',
              style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.15, color: YbsColor.textHero)),
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
                Text(boss ? '격파 3/8 · 다음: No.004' : '12승 9패 · 은메달',
                    style: TextStyle(
                        fontFamily: YbsType.numeric,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: boss ? YbsColor.live400 : YbsColor.go400)),
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
    Widget resultRow(bool win, String label, String score) => Padding(
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
            Expanded(child: Text(label, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody))),
            Text(score,
                style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, color: win ? YbsColor.gold400 : YbsColor.textFaint)),
          ]),
        );

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
              const Text('이어서 도전', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
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
                  child: const Text('말',
                      style: TextStyle(fontFamily: YbsType.display, fontSize: 21, height: 1, color: YbsColor.sky400)),
                ),
                const SizedBox(width: YbsSpace.s3),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No.004 말 끊는 김 과장',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                      Text('최고 71점 · 미격파 · 희귀', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
                    ],
                  ),
                ),
                YbsButton(label: '재도전', variant: YbsButtonVariant.secondary, size: YbsButtonSize.sm, onTap: () => context.go('/bosses')),
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
                resultRow(true, '보스전 · 단호한 미용실 원장', '76'),
                resultRow(false, '배틀 · vs 환불전사_수원', '42:58'),
                resultRow(false, '보스전 · 말 끊는 김 과장', '71'),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('도감 진행', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
                    Text('3/8',
                        style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.live400)),
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
                    child: const FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.375,
                      child: ColoredBox(color: YbsColor.live500),
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
      child: Text('민',
          style: TextStyle(fontFamily: YbsType.display, fontSize: fontSize, height: 1, color: YbsColor.go400)),
    );
  }
}
