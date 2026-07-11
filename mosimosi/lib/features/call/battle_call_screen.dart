import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'call_desktop.dart';

/// 3.3 배틀 통화 화면 ★막다른 방 — B-lite 텍스트 릴레이, 상대 발화 TTS 재생.
/// 프로토타입 BattlePhone.dc.html + InCallDesktopScreen.jsx 이식.
///
/// 가정 (핸드오프 Questions policy):
/// - STT/LLM/WebSocket 미연동. 상태는 목(mock). 마이크 상태 pill을 탭하면
///   player·상담원 → player·민원인 → spectator 순으로 순환한다(세 변형 검수용).
/// - 비밀 목표·AI 코치는 접이식 칩 '표면'만 구현(펼침 패널·실제 데이터 없음).
///   비밀 정보는 서버가 자기 몫만 전송한다는 규칙(Instructions #2)은 배선 단계 사안.
/// - 애니메이션(펄스/이퀄라이저/셰이크)은 스코프 밖 → 정지 상태만.
class BattleCallScreen extends StatefulWidget {
  const BattleCallScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<BattleCallScreen> createState() => _BattleCallScreenState();
}

enum _View { playerAgent, playerClaimant, spectator }

class _Caption {
  const _Caption(this.speaker, this.name, this.text, {this.active = false, this.dim = false});
  final CaptionSpeaker speaker;
  final String name;
  final String text;
  final bool active;
  final bool dim;
}

class _BattleCallScreenState extends State<BattleCallScreen> {
  final _name = '민준';
  final _opp = '환불전사_수원';

  _View _view = _View.playerAgent;

  void _cycleView() {
    setState(() {
      _view = switch (_view) {
        _View.playerAgent => _View.playerClaimant,
        _View.playerClaimant => _View.spectator,
        _View.spectator => _View.playerAgent,
      };
    });
  }

  bool get _isPlayer => _view != _View.spectator;
  bool get _meAgent => _view != _View.playerClaimant; // spectator는 상담원 시점 관전
  String get _myRole => _meAgent ? '상담원' : '민원인';
  String get _oppRole => _meAgent ? '민원인' : '상담원';
  String get _mySide => _isPlayer ? '나' : _name;
  String get _myLabel => '$_mySide · $_myRole';
  String get _oppLabel => '$_opp · $_oppRole';
  String get _scoreLine => _meAgent ? 'MOMENTUM 46 : 54' : 'MOMENTUM 54 : 46';
  bool get _losing => _meAgent;
  double get _greenFraction => _meAgent ? 0.46 : 0.54;
  String get _micLabel => _isPlayer ? '마이크 켜짐 · 자유 대화' : '말하는 중';

  List<_Caption> get _captions {
    // owner 기준 원본 대화 → 내 시점(mine)이면 오른쪽(player), 아니면 왼쪽(boss).
    const lines = [
      ('claimant', '3주째 환불 처리가 안 되고 있잖아요. 오늘은 답을 듣고 끊을 거예요.', false),
      ('agent', '많이 답답하셨겠어요. 어떤 부분이 제일 불편하셨는지 여쭤봐도 될까요?', false),
      ('claimant', '말 돌리지 마세요. 소비자원에 신고하기 전에 환불해 주세요.', true),
    ];
    return [
      for (var i = 0; i < lines.length; i++)
        () {
          final (owner, text, active) = lines[i];
          final mine = (owner == 'agent') == _meAgent;
          return _Caption(
            mine ? CaptionSpeaker.player : CaptionSpeaker.boss,
            mine ? _mySide : _opp,
            text,
            active: active,
            dim: i < lines.length - 1,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final phone = _PhoneBody(state: this);
    if (isDesktop(context)) {
      return Scaffold(
        body: buildCallDesktopStage(
          phone: phone,
          rightLabel: _opp,
          momentum: _greenFraction,
          mission: "상담원이 먼저 '죄송합니다'라고 말하게 만드세요.",
        ),
      );
    }
    return Scaffold(body: SafeArea(bottom: false, child: phone));
  }
}

class _PhoneBody extends StatelessWidget {
  const _PhoneBody({required this.state});
  final _BattleCallScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: YbsColor.bgIncall,
      child: Column(
        children: [
          if (!state._isPlayer) _spectatorHeader(),
          _momentumHeader(),
          _callerBlock(),
          if (state._isPlayer) _ruleFiredCard(),
          if (state._isPlayer) _chips(),
          Expanded(child: _captionList()),
          _micStatus(),
          state._isPlayer ? _playerControls(context) : _spectatorFooter(),
        ],
      ),
    );
  }

  Widget _spectatorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5, vertical: 9),
      decoration: const BoxDecoration(
        color: YbsColor.surfaceInset,
        border: Border(bottom: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: state._name, style: const TextStyle(fontWeight: FontWeight.w700, color: YbsColor.textHero)),
          TextSpan(text: ' · ${state._myRole} 화면'),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textSub),
      ),
    );
  }

  Widget _momentumHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(state._myLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.go400)),
              ),
              const SizedBox(width: YbsSpace.s2),
              Text(state._scoreLine,
                  style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(11), color: YbsColor.textFaint)),
              const SizedBox(width: YbsSpace.s2),
              Expanded(
                child: Text(state._oppLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.live400)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _tugBar(),
          if (state._losing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.south, size: 11, color: YbsColor.live400),
                    SizedBox(width: 5),
                    Text('밀리는 중 −4',
                        style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w700, color: YbsColor.live400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tugBar() {
    return SizedBox(
      height: 12,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: YbsColor.live600, borderRadius: BorderRadius.circular(YbsRadius.full)),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: state._greenFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: YbsColor.go500,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(YbsRadius.full)),
                  boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 14)],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(state._greenFraction * 2 - 1, 0),
            child: Container(width: 3, height: 12, decoration: BoxDecoration(color: YbsColor.white, borderRadius: BorderRadius.circular(2))),
          ),
        ],
      ),
    );
  }

  Widget _callerBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              YbsBadge(label: 'LIVE', tone: BadgeTone.live, pulse: true),
              SizedBox(width: YbsSpace.s2),
              YbsBadge(label: '전화 배틀', tone: BadgeTone.neutral),
            ],
          ),
          const SizedBox(height: YbsSpace.s2),
          const CallTimer(seconds: 72, tone: TimerTone.normal, label: '라운드 1 · 03:00'),
        ],
      ),
    );
  }

  Widget _ruleFiredCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 - 2, YbsSpace.s5, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4, vertical: YbsSpace.s3),
        decoration: BoxDecoration(
          color: YbsColor.live500.withValues(alpha:0.12),
          border: Border.all(color: YbsColor.live600),
          borderRadius: BorderRadius.circular(YbsRadius.md),
          boxShadow: [BoxShadow(color: YbsColor.live500.withValues(alpha:0.18), blurRadius: 20)],
        ),
        child: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, size: 22, color: YbsColor.live400),
            SizedBox(width: YbsSpace.s3 - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('규칙 발동 — 소비자원 언급', style: TextStyle(fontSize: YbsType.sub, fontWeight: FontWeight.w700, height: 1.3, color: YbsColor.live400)),
                  Text('접수 의무가 발생했어요. 접수 절차를 먼저 안내하세요.', style: TextStyle(fontSize: YbsType.micro, height: 1.4, color: YbsColor.textSub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips() {
    Widget chip({required Widget leading, required String label, Widget? badge, required Color color, required Color border, required Color bg}) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s4 - 2),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(YbsRadius.full)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: color)),
            if (badge != null) ...[const SizedBox(width: 7), badge],
            const SizedBox(width: 7),
            Icon(Icons.keyboard_arrow_down, size: 14, color: color),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3, YbsSpace.s5, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: YbsSpace.s2 + 2,
        runSpacing: YbsSpace.s2,
        children: [
          chip(
            leading: const Icon(Icons.lock_outline, size: 14, color: YbsColor.go300),
            label: '비밀 목표',
            color: YbsColor.go300,
            border: YbsColor.go600,
            bg: YbsColor.go500.withValues(alpha:0.08),
          ),
          chip(
            leading: const Text('AI 코치', style: TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.gold300)),
            label: '',
            badge: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: YbsColor.gold400, borderRadius: BorderRadius.circular(YbsRadius.full)),
              child: const Text('1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: YbsColor.textOnGold)),
            ),
            color: YbsColor.gold300,
            border: YbsColor.gold500,
            bg: YbsColor.gold400.withValues(alpha:0.10),
          ),
        ],
      ),
    );
  }

  Widget _captionList() {
    final caps = state._captions;
    // 전사 로그는 하단 고정 + 넘치면 스크롤(reverse). 말풍선이 남은 높이를 넘어도 오버플로우 없음.
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s4),
      child: Column(
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

  Widget _micStatus() {
    return Padding(
      padding: const EdgeInsets.only(bottom: YbsSpace.s3),
      child: Center(
        // 마이크 pill 탭 → 세 변형(player 상담원/민원인, spectator) 순환 (mock).
        child: GestureDetector(
          onTap: state._cycleView,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s5 - 2),
            decoration: BoxDecoration(
              color: YbsColor.go500.withValues(alpha:0.08),
              border: Border.all(color: YbsColor.go600),
              borderRadius: BorderRadius.circular(YbsRadius.full),
              boxShadow: [BoxShadow(color: YbsColor.go500.withValues(alpha:0.12), blurRadius: 18)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      child: Container(width: 3, height: 16, decoration: BoxDecoration(color: YbsColor.go400, borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
                ),
                const SizedBox(width: YbsSpace.s3 - 2),
                Text(state._micLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: YbsColor.go300)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s3 - 2, YbsSpace.s5, YbsSpace.s6 + 2),
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        border: Border(top: BorderSide(color: YbsColor.borderIncall)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CallIconButton(icon: Icons.mic, label: '음소거'),
          const SizedBox(width: YbsSpace.s6 + 2),
          const CallIconButton(icon: Icons.volume_up, label: '스피커'),
          const SizedBox(width: YbsSpace.s6 + 2),
          CallIconButton(
              icon: Icons.call_end,
              label: '종료',
              kind: CallButtonKind.endCall,
              onTap: () => context.go('/battle/${state.widget.roomId}/result')),
        ],
      ),
    );
  }

  Widget _spectatorFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4, YbsSpace.s5, YbsSpace.s5),
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
              style: TextStyle(fontFamily: YbsType.numeric, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: YbsType.labelTracking(11), color: YbsColor.textFaint)),
        ],
      ),
    );
  }
}
