import 'package:flutter/material.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 5. 관전 화면 (데모 프로젝션) — 디자인 C 섹션 이식.
/// 상단: LIVE·SPECTATOR + 양측 프로필 + 기세 바 + 타이머.
/// 본문: [상대 폰 | 캐스터 중계 + 판정 기준 | 내 폰] 3열 (모바일은 세로 스택).
/// 비밀 목표/규칙 카드 비노출 (서버가 관전 스트림에서 원천 제외 — 규칙 #2). 목 데이터.
class BattleWatchScreen extends StatelessWidget {
  const BattleWatchScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      backgroundColor: YbsColor.bgIncall,
      body: SafeArea(
        child: Column(
          children: [
            _topStrip(),
            Expanded(
              child: desktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s8, vertical: YbsSpace.s6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _phoneMock(isAgent: false)),
                          const SizedBox(width: YbsSpace.s6),
                          SizedBox(width: 340, child: _centerColumn()),
                          const SizedBox(width: YbsSpace.s6),
                          Expanded(child: _phoneMock(isAgent: true)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(YbsSpace.s5),
                      children: [
                        _casterPanel(),
                        const SizedBox(height: YbsSpace.s4),
                        SizedBox(height: 420, child: _phoneMock(isAgent: false)),
                        const SizedBox(height: YbsSpace.s4),
                        SizedBox(height: 420, child: _phoneMock(isAgent: true)),
                        const SizedBox(height: YbsSpace.s4),
                        _criteriaPanel(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 상단 88px 스트립 ----
  Widget _topStrip() {
    Widget profile({required bool agent, required bool alignRight}) {
      final accent = agent ? YbsColor.go400 : YbsColor.live400;
      final border = agent ? YbsColor.go600 : YbsColor.live600;
      final avatar = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: YbsColor.surfaceInset,
          gradient: RadialGradient(
            center: const Alignment(0, -0.24),
            radius: 0.72,
            colors: [accent.withValues(alpha: 0.25), Colors.transparent],
          ),
          border: Border.all(color: border, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(agent ? '민' : '환',
            style: TextStyle(fontFamily: YbsType.display, fontSize: 15, height: 1, color: accent)),
      );
      final texts = Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(agent ? '민준' : '환불전사_수원',
              style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, height: 1.2, color: accent)),
          Text(agent ? '상담원' : '민원인', style: const TextStyle(fontSize: 11, color: YbsColor.textSub)),
        ],
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: alignRight ? [texts, const SizedBox(width: YbsSpace.s2 + 2), avatar] : [avatar, const SizedBox(width: YbsSpace.s2 + 2), texts],
      );
    }

    return Container(
      height: YbsLayout.stageTopH,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s8),
      decoration: const BoxDecoration(
        color: YbsColor.surfaceIncall,
        border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Row(
        children: [
          const YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
          const SizedBox(width: YbsSpace.s2 + 2),
          const YbsBadge(label: 'SPECTATOR', tone: BadgeTone.neutral, mono: true),
          const SizedBox(width: YbsSpace.s6),
          profile(agent: false, alignRight: false),
          const SizedBox(width: YbsSpace.s6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(YbsRadius.full),
                  child: Container(
                    height: 14,
                    color: YbsColor.go600,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.54,
                      child: Container(
                        decoration: BoxDecoration(
                          color: YbsColor.live500,
                          boxShadow: [BoxShadow(color: YbsColor.liveGlow, blurRadius: 14)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('54 : 46',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: 13, fontWeight: FontWeight.w600, color: YbsColor.textSub)),
              ],
            ),
          ),
          const SizedBox(width: YbsSpace.s6),
          profile(agent: true, alignRight: true),
          const SizedBox(width: YbsSpace.s6),
          const CallTimer(seconds: 72, label: '라운드 1 · 03:00'),
        ],
      ),
    );
  }

  // ---- 폰 목업 (spectator 뷰 간이 재현) ----
  Widget _phoneMock({required bool isAgent}) {
    final glow = isAgent ? YbsColor.go500 : YbsColor.live500;
    final lines = isAgent
        ? const [
            ('많이 답답하셨겠어요. 어떤 부분이 제일 불편하셨는지 여쭤봐도 될까요?', false),
            ('우선 접수번호 드리고 담당 부서에서 바로 연락드리도록 할게요.', true),
          ]
        : const [
            ('3주째 환불 처리가 안 되고 있잖아요. 오늘은 답을 듣고 끊을 거예요.', false),
            ('말 돌리지 마세요. 소비자원에 신고하기 전에 환불해 주세요.', true),
          ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: YbsLayout.stagePhoneW),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E3440), Color(0xFF12151C), Color(0xFF232936)],
            ),
            border: Border.all(color: const Color(0xFF3C4454)),
            borderRadius: BorderRadius.circular(48),
            boxShadow: [...YbsShadow.pop, BoxShadow(color: glow.withValues(alpha: 0.10), blurRadius: 40)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Container(
              color: YbsColor.bgIncall,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: const BoxDecoration(
                      color: YbsColor.surfaceInset,
                      border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: isAgent ? '민준' : '환불전사_수원',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                        TextSpan(text: ' · ${isAgent ? '상담원' : '민원인'} 화면'),
                      ]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(YbsSpace.s4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (text, active) in lines)
                            Padding(
                              padding: const EdgeInsets.only(top: YbsSpace.s3),
                              child: LiveCaption(
                                speaker: isAgent ? CaptionSpeaker.player : CaptionSpeaker.boss,
                                name: isAgent ? '민준' : '환불전사_수원',
                                text: text,
                                active: active,
                                dim: !active,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: YbsSpace.s4 - 2),
                    decoration: const BoxDecoration(
                      color: Color(0x59000000),
                      border: Border(top: BorderSide(color: YbsColor.borderIncall)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: YbsColor.live500, shape: BoxShape.circle)),
                        const SizedBox(width: YbsSpace.s2),
                        Text('SPECTATOR · 실시간 관전',
                            style: TextStyle(
                                fontFamily: YbsType.numeric,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: YbsType.labelTracking(11),
                                color: YbsColor.textFaint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 중앙: 캐스터 + 판정 기준 ----
  Widget _centerColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _casterPanel()),
        const SizedBox(height: YbsSpace.s6),
        _criteriaPanel(),
      ],
    );
  }

  Widget _casterPanel() {
    Widget line(String t, String text, {bool hot = false}) => Padding(
          padding: const EdgeInsets.only(bottom: YbsSpace.s4 - 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t,
                  style: TextStyle(
                      fontFamily: YbsType.numeric,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hot ? YbsColor.gold400 : YbsColor.textFaint)),
              const SizedBox(width: YbsSpace.s2 + 2),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: hot ? 15 : YbsType.sub,
                        fontWeight: hot ? FontWeight.w700 : FontWeight.w400,
                        height: 1.55,
                        color: hot ? YbsColor.gold300 : YbsColor.textSub)),
              ),
            ],
          ),
        );
    return HudPanel(
      title: '캐스터 중계',
      label: 'AUTO',
      tone: HudTone.gold,
      live: true,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          line('00:12', '민원인, 시작부터 강하게 나옵니다. 3주 묵은 분노!'),
          line('00:29', '상담원, 공감으로 받아냅니다. 교과서적인 수비.'),
          line('01:12', '나왔습니다 — 소비자원 카드! 상담원, 여기서 말리면 무너집니다.', hot: true),
        ],
      ),
    );
  }

  Widget _criteriaPanel() {
    return const HudPanel(
      title: '판정 기준',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('기세 = 발화 주도권 + 근거 제시 + 침묵 관리',
              style: TextStyle(fontSize: 13, height: 1.55, color: YbsColor.textSub)),
          SizedBox(height: YbsSpace.s2),
          Text('비밀 목표와 규칙 카드는 종료 후 공개됩니다.',
              style: TextStyle(fontSize: 13, height: 1.55, color: YbsColor.textFaint)),
        ],
      ),
    );
  }
}
