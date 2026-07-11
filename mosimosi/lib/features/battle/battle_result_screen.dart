import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 3.4 판정 대기 + 3.5 배틀 판정 — 디자인 J 섹션 이식.
/// 탭 A 판정(루브릭) / 탭 B 비밀 공개(페이오프) / 탭 C 내 리포트.
/// 비주얼 목: 심판·서버 연동은 P1. 2.5초 로딩 연출 후 목 결과.
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  bool _judging = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _judging = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_judging) {
      // ---- 3.4 판정 대기 ----
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: YbsColor.gold400),
              SizedBox(height: YbsSpace.s5),
              Text('심판이 통화 전체를 검토 중…',
                  style: TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textBody)),
              SizedBox(height: YbsSpace.s2),
              Text('과정 점수로 판정해요 — 버티기는 안 통해요',
                  style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
              child: Row(children: [
                Expanded(child: _tabButton('판정', 0)),
                const SizedBox(width: 6),
                Expanded(child: _tabButton('비밀 공개', 1)),
                const SizedBox(width: 6),
                Expanded(child: _tabButton('내 리포트', 2)),
              ]),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _verdictTab(),
                1 => _secretsTab(),
                _ => _myReportTab(),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3 + 2, YbsSpace.s5, 30),
              child: Row(children: [
                Expanded(
                  child: YbsButton(
                    label: '재매칭',
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: () => context.go('/battle'),
                  ),
                ),
                const SizedBox(width: YbsSpace.s2 + 2),
                SizedBox(
                  width: 90,
                  child: YbsButton(
                    label: '홈',
                    variant: YbsButtonVariant.ghost,
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: () => context.go('/home'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? YbsColor.surfaceCardHover : Colors.transparent,
          border: Border.all(color: active ? YbsColor.borderStrong : YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.sm + 2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? YbsColor.textHero : YbsColor.textSub)),
      ),
    );
  }

  Widget _card({required List<Widget> children, Color? border, Color? bg, Color? glow}) => Container(
        padding: const EdgeInsets.all(YbsSpace.s4),
        decoration: BoxDecoration(
          color: bg ?? YbsColor.surfaceCard,
          border: Border.all(color: border ?? YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md + 2),
          boxShadow: glow == null ? null : [BoxShadow(color: glow, blurRadius: 20)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _cardLabel(String label, {Color color = YbsColor.textFaint}) => Text(label,
      style: TextStyle(
          fontSize: YbsType.micro,
          fontWeight: FontWeight.w700,
          letterSpacing: YbsType.labelTracking(YbsType.micro) / 2,
          color: color));

  // ---- 탭 A 판정 ----
  Widget _verdictTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
      children: [
        const Center(
          child: VerdictBanner(victory: true, title: '승리', subtitle: '민준 님이 기세 싸움을 가져왔어요'),
        ),
        const SizedBox(height: YbsSpace.s4 + 2),
        Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('나 · 상담원', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go400)),
              Text('최종 기세 62 : 38',
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
              Text('환불전사_수원', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.live400)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(YbsRadius.full),
            child: Container(
              height: 10,
              color: YbsColor.live600,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.62,
                child: Container(
                  decoration: BoxDecoration(color: YbsColor.go500, boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)]),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: YbsSpace.s4 + 2),
        _card(children: [
          _cardLabel('나 · 상담원 루브릭'),
          const SizedBox(height: YbsSpace.s4 - 2),
          const RubricScore(label: '대안 제시', score: 4, comment: '「부분 환불 + 무료 회수」 — 근거 있는 대안이었어요'),
          const SizedBox(height: YbsSpace.s4 - 2),
          const RubricScore(label: '접수 의무 이행', score: 5, comment: '소비자원 언급 직후 「먼저 접수해 드릴게요」 — 규칙 완벽 대응'),
          const SizedBox(height: YbsSpace.s4 - 2),
          const RubricScore(label: '감정 관리', score: 3, comment: '01:40 언성이 잠깐 올라갔어요'),
        ]),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(children: [
          _cardLabel('환불전사_수원 · 민원인 루브릭'),
          const SizedBox(height: YbsSpace.s4 - 2),
          const RubricScore(label: '근거 없는 거절 압박', score: 4, comment: '「3주째」 반복으로 시간 압박을 잘 썼어요'),
          const SizedBox(height: YbsSpace.s4 - 2),
          const RubricScore(label: '상급자 요구 (에스컬레이션)', score: 2, comment: '팀장 연결 요구 타이밍을 놓쳤어요'),
        ]),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  // ---- 탭 B 비밀 공개 ----
  Widget _secretsTab() {
    Widget resultTag(String label, {required bool good}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: good ? YbsColor.go600 : YbsColor.live600),
            borderRadius: BorderRadius.circular(YbsRadius.xs),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: good ? YbsColor.go400 : YbsColor.live400)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, 26, YbsSpace.s5, 0),
      children: [
        const Center(
          child: Text('서로의 패, 공개!',
              style: TextStyle(fontFamily: YbsType.display, fontSize: 26, height: 1.2, color: YbsColor.gold300)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('이제야 보이는 3분의 진실', style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
        ),
        const SizedBox(height: YbsSpace.s5),
        _card(
          border: YbsColor.go600,
          bg: YbsColor.go500.withValues(alpha: 0.06),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _cardLabel('나 · 상담원의 비밀 목표', color: YbsColor.go400),
              resultTag('달성 +20', good: true),
            ]),
            const SizedBox(height: YbsSpace.s2 + 2),
            const Text('환불 없이 만족도 3점 이상으로 종료',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s2),
            const Text('종료 설문 만족도 3점 — 아슬아슬하게 성공',
                style: TextStyle(fontSize: YbsType.micro, height: 1.5, color: YbsColor.textSub)),
          ],
        ),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(
          border: YbsColor.borderIncall,
          bg: YbsColor.live500.withValues(alpha: 0.05),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _cardLabel('나의 규칙 카드 · 발동됨', color: YbsColor.live400),
              resultTag('대응 성공', good: true),
            ]),
            const SizedBox(height: YbsSpace.s2 + 2),
            const Text('소비자원 신고 언급 시 접수 의무 발생',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s2),
            const Text('01:12 발동 → 01:26 접수 안내 — 14초 만에 대응',
                style: TextStyle(fontSize: YbsType.micro, height: 1.5, color: YbsColor.textSub)),
          ],
        ),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(
          border: YbsColor.live600,
          bg: YbsColor.live500.withValues(alpha: 0.06),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _cardLabel('환불전사_수원 · 민원인의 비밀 목표', color: YbsColor.live400),
              resultTag('실패', good: false),
            ]),
            const SizedBox(height: YbsSpace.s2 + 2),
            const Text('통화 2분 안에 「전액 환불」 확답 받아내기',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.55, color: YbsColor.textHero)),
            const SizedBox(height: YbsSpace.s2),
            const Text('그래서 초반부터 그렇게 몰아붙였던 거예요',
                style: TextStyle(fontSize: YbsType.micro, height: 1.5, color: YbsColor.textSub)),
          ],
        ),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(children: [
          _cardLabel('결정적 발언'),
          const SizedBox(height: 6),
          const Text('「신고하시기 전에 제가 먼저 접수해 드릴게요. 접수번호 바로 드립니다.」',
              style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
          const SizedBox(height: 6),
          const Text('01:26 · 기세 +12',
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, color: YbsColor.textFaint)),
        ]),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }

  // ---- 탭 C 내 리포트 ----
  Widget _myReportTab() {
    Widget stat(String label, String value) => Expanded(
          child: _card(children: [
            Text(label, style: const TextStyle(fontSize: 11, color: YbsColor.textFaint)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: 22, fontWeight: FontWeight.w600, height: 1.1, color: YbsColor.go400)),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s5, YbsSpace.s5, 0),
      children: [
        Row(children: [
          stat('군말', '4회'),
          const SizedBox(width: YbsSpace.s3),
          stat('침묵 (2초+)', '1회'),
        ]),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(children: [
          _cardLabel('결정적 발언'),
          const SizedBox(height: 6),
          const Text('「신고하시기 전에 제가 먼저 접수해 드릴게요. 접수번호 바로 드립니다.」',
              style: TextStyle(fontSize: YbsType.sub, height: 1.55, color: YbsColor.textBody)),
          const SizedBox(height: 6),
          const Text('01:26 · 기세 +12',
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, color: YbsColor.textFaint)),
        ]),
        const SizedBox(height: YbsSpace.s4 - 2),
        _card(
          border: YbsColor.gold500,
          bg: YbsColor.gold400.withValues(alpha: 0.05),
          children: [
            _cardLabel('이렇게 말했다면', color: YbsColor.gold300),
            const SizedBox(height: YbsSpace.s2 + 2),
            const Text('「고객님, 진정하세요.」',
                style: TextStyle(fontSize: 13, color: YbsColor.textFaint, decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 4),
            const Text('→ 「많이 답답하셨겠어요. 지금 바로 확인할게요.」',
                style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textBody)),
          ],
        ),
        const SizedBox(height: YbsSpace.s4),
      ],
    );
  }
}
