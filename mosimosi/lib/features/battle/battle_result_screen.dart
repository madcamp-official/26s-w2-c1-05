import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';

/// 3.4 판정 대기 + 3.5 배틀 결과 (탭 A 판정 / B 비밀 공개 / C 리포트).
/// 비주얼 목: 심판·서버 연동은 P1. 2.5초 로딩 연출 후 목 결과 표시.
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  bool _judging = true;

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
    // ---- 3.5 결과 ----
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const SizedBox(height: YbsSpace.s8),
              const Text('WIN',
                  style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.poster, height: 1.15, color: YbsColor.gold400)),
              const SizedBox(height: YbsSpace.s1),
              const Text('나 (상담원) vs 환불전사_수원 (민원인)',
                  style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
              const SizedBox(height: YbsSpace.s4),
              // 최종 모멘텀
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s8),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                    child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        Expanded(flex: 58, child: Container(color: YbsColor.go500)),
                        Expanded(flex: 42, child: Container(color: YbsColor.live600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('최종 모멘텀 58 : 42',
                      style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, color: YbsColor.textFaint)),
                ]),
              ),
              const SizedBox(height: YbsSpace.s4),
              const TabBar(
                indicatorColor: YbsColor.gold400,
                labelColor: YbsColor.textHero,
                unselectedLabelColor: YbsColor.textFaint,
                tabs: [Tab(text: '판정'), Tab(text: '비밀 공개'), Tab(text: '리포트')],
              ),
              Expanded(child: TabBarView(children: [_verdict(), _secrets(), _report()])),
              _cta(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rubricRow(String item, int score, String evidence) {
    return Container(
      margin: const EdgeInsets.only(bottom: YbsSpace.s3),
      padding: const EdgeInsets.all(YbsSpace.s4),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(item, style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textBody))),
            Text('+$score',
                style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.sub, fontWeight: FontWeight.w600, color: YbsColor.go400)),
          ]),
          const SizedBox(height: YbsSpace.s1),
          Text('“$evidence”', style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textFaint)),
        ],
      ),
    );
  }

  Widget _verdict() {
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        _rubricRow('감정 진정 유도', 12, '많이 답답하셨겠어요. 어떤 부분이 제일 불편하셨는지…'),
        _rubricRow('규정 근거 설명', 10, '내부 규정 7조에 따라 접수 후 3일 내 처리가 원칙이라…'),
        _rubricRow('대안 제시', 8, '우선 접수번호를 드리고 담당 부서에서 바로 연락드릴게요.'),
        Container(
          padding: const EdgeInsets.all(YbsSpace.s4),
          decoration: BoxDecoration(
            color: YbsColor.live500.withValues(alpha: 0.08),
            border: Border.all(color: YbsColor.live600),
            borderRadius: BorderRadius.circular(YbsRadius.md),
          ),
          child: const Text('감점 −6 · 같은 안내 반복 2회 (앵무새 응대)',
              style: TextStyle(fontSize: YbsType.sub, color: YbsColor.live400)),
        ),
      ],
    );
  }

  Widget _secrets() {
    Widget card(String who, String goal, bool achieved, Color tone) => Container(
          margin: const EdgeInsets.only(bottom: YbsSpace.s3),
          padding: const EdgeInsets.all(YbsSpace.s4),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: tone),
            borderRadius: BorderRadius.circular(YbsRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(who, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: tone)),
                const Spacer(),
                Text(achieved ? '달성' : '실패',
                    style: TextStyle(
                        fontFamily: YbsType.display,
                        fontSize: YbsType.sub,
                        color: achieved ? YbsColor.gold400 : YbsColor.textFaint)),
              ]),
              const SizedBox(height: YbsSpace.s2),
              Text(goal, style: const TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w600, height: 1.5, color: YbsColor.textHero)),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        const Text('서로의 비밀 목표가 공개됐어요!',
            style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textSub)),
        const SizedBox(height: YbsSpace.s3),
        card('나 · 상담원', '환불 없이 통화를 만족도 3점 이상으로 종료시켜라.', true, YbsColor.go400),
        card('환불전사_수원 · 민원인', '환불 확답을 받아내라.', false, YbsColor.live400),
      ],
    );
  }

  Widget _report() {
    return ListView(
      padding: const EdgeInsets.all(YbsSpace.s5),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: YbsSpace.s4),
          padding: const EdgeInsets.all(YbsSpace.s4),
          decoration: BoxDecoration(
            color: YbsColor.gold400.withValues(alpha: 0.10),
            border: Border.all(color: YbsColor.gold500),
            borderRadius: BorderRadius.circular(YbsRadius.md),
          ),
          child: const Text('오늘의 한마디 — 공감 한 문장이 규정 열 문장보다 강했어요.',
              style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.gold300)),
        ),
        Container(
          padding: const EdgeInsets.all(YbsSpace.s4),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.md),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('같은 안내를 반복하던 1:42 구간', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
              SizedBox(height: YbsSpace.s1),
              Text('→ "그럼 이렇게 해 보면 어떨까요?"로 대안 전환',
                  style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.go300)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, YbsSpace.s5),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: YbsColor.borderSoft))),
      child: Row(children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: YbsColor.go500,
              foregroundColor: YbsColor.textOnGo,
              minimumSize: const Size.fromHeight(YbsSpace.hitMin + 8),
            ),
            onPressed: () => context.go('/battle'),
            child: const Text('재매칭', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: YbsSpace.s3),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: YbsColor.textBody,
              side: const BorderSide(color: YbsColor.borderStrong),
              minimumSize: const Size.fromHeight(YbsSpace.hitMin + 8),
            ),
            onPressed: () => context.go('/home'),
            child: const Text('홈으로'),
          ),
        ),
      ]),
    );
  }
}
