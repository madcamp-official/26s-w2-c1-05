import 'package:flutter/material.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'call_desktop.dart';

/// 2.3 통화 화면 (싱글) ★막다른 방 — 통화 중 GNB 숨김, 이탈은 끊기만.
/// 프로토타입 BossCallPhone.dc.html + InCallDesktopScreen.jsx 이식.
///
/// 가정 (핸드오프 Questions policy):
/// - STT/LLM 미연동. 상태는 목(mock)이며, push-to-talk 버튼을 누르면
///   normal → silence(침묵 경고) → finalRush(막판 30초) 순으로 순환한다
///   (실제 UI를 새로 만들지 않고 세 상태를 검수 가능하게 하기 위함).
/// - 침묵 경고(silence) 비주얼은 프로토타입 'silence' variant 그대로:
///   앰버 인내심 게이지 + "N초째 침묵" 이벤트 카드 + 달성조건 체크리스트 펼침.
/// - 애니메이션(펄스/셰이크/링/오버레이 글로우)은 스코프 밖 → 정지 상태만.
class BossCallScreen extends StatefulWidget {
  const BossCallScreen({super.key, required this.bossId});

  final String bossId;

  @override
  State<BossCallScreen> createState() => _BossCallScreenState();
}

enum _Phase { normal, silence, finalRush }

class _Caption {
  const _Caption(this.speaker, this.name, this.text, {this.active = false, this.dim = false});
  final CaptionSpeaker speaker;
  final String name;
  final String text;
  final bool active;
  final bool dim;
}

class _BossCallScreenState extends State<BossCallScreen> {
  _Phase _phase = _Phase.normal;

  void _advancePhase() {
    setState(() {
      _phase = switch (_phase) {
        _Phase.normal => _Phase.silence,
        _Phase.silence => _Phase.finalRush,
        _Phase.finalRush => _Phase.normal,
      };
    });
  }

  bool get _isSilence => _phase == _Phase.silence;

  int get _seconds => switch (_phase) { _Phase.normal => 84, _Phase.silence => 107, _Phase.finalRush => 153 };
  TimerTone get _timerTone => switch (_phase) { _Phase.normal => TimerTone.normal, _Phase.silence => TimerTone.warning, _Phase.finalRush => TimerTone.critical };
  String get _patienceLabel => switch (_phase) { _Phase.normal => '64%', _Phase.silence => '38%', _Phase.finalRush => '16%' };
  double get _patienceFraction => switch (_phase) { _Phase.normal => 0.64, _Phase.silence => 0.38, _Phase.finalRush => 0.16 };
  Color get _patienceColor => _isSilence ? YbsColor.amber400 : YbsColor.live500;
  double get _momentum => switch (_phase) { _Phase.normal => 0.55, _Phase.silence => 0.42, _Phase.finalRush => 0.7 };

  List<_Caption> get _captions => switch (_phase) {
        _Phase.normal => const [
            _Caption(CaptionSpeaker.player, '나', '안녕하세요. 지난주 구매한 이어폰이 불량이라 환불 요청드려요.', dim: true),
            _Caption(CaptionSpeaker.boss, '상담원', '고객님, 환불은 안 됩니다. 규정이에요.'),
            _Caption(CaptionSpeaker.player, '나', '그 규정이 몇 조 몇 항인지 확인해 주시겠어요?', active: true),
          ],
        _Phase.silence => const [
            _Caption(CaptionSpeaker.player, '나', '환불이 아니라 적립금이요?', dim: true),
            _Caption(CaptionSpeaker.boss, '상담원', '네, 규정상 환불은 안 되고 적립금 5,000원만 가능합니다. 괜찮으시죠?', active: true),
          ],
        _Phase.finalRush => const [
            _Caption(CaptionSpeaker.boss, '상담원', '규정 7조 2항, 단순 변심 환불 불가 조항입니다.', dim: true),
            _Caption(CaptionSpeaker.player, '나', '그 조항은 변심일 때죠. 이건 하자 상품이에요. 환불 처리해 주세요.', active: true),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final phone = _PhoneBody(state: this);
    if (isDesktop(context)) {
      return Scaffold(
        body: buildCallDesktopStage(
          phone: phone,
          rightLabel: '환불의 벽',
          momentum: _momentum,
          mission: '환불 규정의 조항 번호를 받아내세요.',
        ),
      );
    }
    return Scaffold(body: SafeArea(bottom: false, child: phone));
  }
}

/// 폰 본문 — 모바일 화면 그 자체이자 데스크톱 폰 목업 안에 재사용되는 위젯 트리.
class _PhoneBody extends StatelessWidget {
  const _PhoneBody({required this.state});
  final _BossCallScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: YbsColor.bgApp,
      child: Column(
        children: [
          _patienceHeader(),
          _callerBlock(),
          _eventCard(),
          Expanded(child: _captionList()),
          state._isSilence ? _conditionChecklist() : _conditionChip(),
          _bottomBar(context),
        ],
      ),
    );
  }

  Widget _patienceHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('보스 인내심',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: YbsType.labelTracking(11), color: YbsColor.live400)),
              Text(state._patienceLabel,
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.live400)),
            ],
          ),
          const SizedBox(height: 6),
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
                widthFactor: state._patienceFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: state._patienceColor,
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                    boxShadow: [BoxShadow(color: state._patienceColor.withValues(alpha:0.4), blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callerBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, 0),
      child: Column(
        children: [
          const YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
          const SizedBox(height: YbsSpace.s2),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: YbsColor.surfaceInset,
              border: Border.all(color: YbsColor.live600, width: 2),
              gradient: RadialGradient(center: const Alignment(0, -0.24), radius: 0.72, colors: [YbsColor.live500.withValues(alpha:0.30), Colors.transparent]),
              boxShadow: [BoxShadow(color: YbsColor.live500.withValues(alpha:0.22), blurRadius: 24)],
            ),
            alignment: Alignment.center,
            child: const Text('환', style: TextStyle(fontFamily: YbsType.display, fontSize: 30, height: 1, color: YbsColor.live400)),
          ),
          const SizedBox(height: YbsSpace.s2),
          const Text('환불 불가 3연벙 상담원',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: YbsType.display, fontSize: 23, height: 1.2, color: YbsColor.textHero)),
          const SizedBox(height: 2),
          const Text('최종 보스 · 급배송 고객센터 · 제한 시간 03:00',
              style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s2),
          CallTimer(seconds: state._seconds, tone: state._timerTone, label: '통화 시간'),
        ],
      ),
    );
  }

  Widget _eventCard() {
    final (bg, border, glow, icon, iconColor, title, titleColor, sub) = switch (state._phase) {
      _Phase.normal => (
          YbsColor.go500.withValues(alpha:0.10), YbsColor.go600, YbsColor.go500.withValues(alpha:0.12), Icons.check_circle_outline, YbsColor.go400,
          '달성 조건 ① 완료', YbsColor.go300, '거절 근거(규정 조항) 확인 — 1/3'),
      _Phase.silence => (
          YbsColor.amber400.withValues(alpha:0.10), YbsColor.amber400.withValues(alpha:0.6), YbsColor.amber400.withValues(alpha:0.15), Icons.warning_amber_rounded, YbsColor.amber400,
          '4초째 침묵', YbsColor.amber400, '보스 인내심이 빠르게 떨어지고 있어요'),
      _Phase.finalRush => (
          YbsColor.live500.withValues(alpha:0.12), YbsColor.live600, YbsColor.live500.withValues(alpha:0.18), Icons.schedule, YbsColor.live400,
          '남은 시간 27초', YbsColor.live400, '조건 ③ 환불 확답이 아직이에요'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(YbsRadius.md),
          boxShadow: [BoxShadow(color: glow, blurRadius: 20)],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: YbsSpace.s3 - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, height: 1.3, color: titleColor)),
                  Text(sub, style: const TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textSub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _captionList() {
    final caps = state._captions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < caps.length; i++) ...[
            if (i > 0) const SizedBox(height: YbsSpace.s3),
            LiveCaption(speaker: caps[i].speaker, name: caps[i].name, text: caps[i].text, active: caps[i].active, dim: caps[i].dim),
          ],
        ],
      ),
    );
  }

  Widget _conditionChip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: YbsSpace.s3 - 2),
      child: Center(
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: BorderRadius.circular(YbsRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('달성 조건 ', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.textSub)),
              Text(state._phase == _Phase.finalRush ? '2/3' : '1/3',
                  style: const TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.go400)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up, size: 14, color: YbsColor.textSub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conditionChecklist() {
    Widget item({required Widget marker, required Widget label}) => Padding(
          padding: const EdgeInsets.only(bottom: YbsSpace.s2),
          child: Row(children: [marker, const SizedBox(width: YbsSpace.s3 - 2), Expanded(child: label)]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(YbsSpace.s5, 0, YbsSpace.s5, YbsSpace.s2 + 2),
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3 + 2),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                const TextSpan(children: [
                  TextSpan(text: '달성 조건 '),
                  TextSpan(text: '1/3', style: TextStyle(fontFamily: YbsType.numeric, color: YbsColor.go400)),
                ]),
                style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textSub),
              ),
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('접기', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
                Icon(Icons.keyboard_arrow_down, size: 14, color: YbsColor.textFaint),
              ]),
            ],
          ),
          const SizedBox(height: YbsSpace.s2 + 2),
          item(
            marker: const Icon(Icons.check, size: 16, color: YbsColor.go400),
            label: const Text('거절 근거(규정 조항) 확인',
                style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textFaint, decoration: TextDecoration.lineThrough)),
          ),
          item(
            marker: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: YbsColor.amber400, width: 2))),
            label: Text.rich(
              const TextSpan(children: [
                TextSpan(text: '대안 제시에 물러서지 않기 '),
                TextSpan(text: '지금', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: YbsColor.amber400)),
              ]),
              style: const TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, color: YbsColor.textHero),
            ),
          ),
          item(
            marker: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: YbsColor.ink500, width: 2))),
            label: const Text('환불 확답 또는 접수번호 받기', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, YbsSpace.s6 + 2),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        border: Border(top: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallIconButton(
                icon: Icons.call_end,
                label: '종료',
                kind: CallButtonKind.endCall,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: YbsSpace.s3),
              Expanded(
                child: GestureDetector(
                  onTap: state._advancePhase,
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: YbsColor.go500,
                      borderRadius: BorderRadius.circular(YbsRadius.lg),
                      border: Border.all(color: YbsColor.go600),
                      boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 24)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic, size: 24, color: YbsColor.textOnGo),
                        const SizedBox(width: YbsSpace.s2 + 2),
                        Text(state._isSilence ? '지금 말할 차례예요' : '누르는 동안 말하기',
                            style: const TextStyle(fontFamily: YbsType.body, fontSize: 19, fontWeight: FontWeight.w800, color: YbsColor.textOnGo)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: YbsSpace.s2 + 2),
          const Text('손을 떼면 음성이 전송돼요', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
        ],
      ),
    );
  }
}
