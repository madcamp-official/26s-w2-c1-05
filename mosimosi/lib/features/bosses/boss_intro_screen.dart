import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/bosses.dart';
import '../../core/models/boss.dart';
import '../../core/sound_service.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 2a. 인트로 씬 — 메신저 스토리 (보스전 도입, 디자인 IntroScene).
/// 메시지가 순차 재생되고(친구 메시지 앞엔 타이핑 표시), 마지막에
/// INCOMING BOSS 구분선 + 고객센터 번호 + 발신 버튼으로 보스전 진입.
/// 데스크톱은 인콜과 동일한 폰 스테이지(중앙 390px 프레임) 처리.
class BossIntroScreen extends StatefulWidget {
  const BossIntroScreen({super.key, required this.bossId});

  final String bossId;

  @override
  State<BossIntroScreen> createState() => _BossIntroScreenState();
}

class _BossIntroScreenState extends State<BossIntroScreen>
    with SingleTickerProviderStateMixin {
  Boss? get _boss => bossById(widget.bossId);
  IntroStory? get _story => _boss?.introStory;

  // ---- 재생 페이스 (읽는 호흡 기준 튜닝 지점) ----
  static const _firstDelay = Duration(milliseconds: 900); // 진입 → 첫 메시지
  static const _messageGap = Duration(milliseconds: 1500); // 메시지 사이
  static const _typingLead = Duration(milliseconds: 700); // 친구 차례 → 타이핑 표시
  static const _typingHold = Duration(milliseconds: 1600); // 타이핑 유지
  static const _finalDelay = Duration(milliseconds: 1100); // 마지막 → 발신 카드

  int _visible = 0; // 재생된 메시지 수
  bool _typing = false; // 친구 메시지 도착 전 타이핑 인디케이터
  bool _showFinal = false; // INCOMING BOSS + 발신 카드
  Timer? _timer;
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(); // 타이핑 점·발신 버튼 펄스 공용 루프

  @override
  void initState() {
    super.initState();
    SoundService.instance.suppressBgm(); // 인트로 스토리 동안 로비 BGM 음소거
    final story = _story;
    if (story == null) {
      // 스토리 없는 보스 — 인트로 없이 바로 통화로.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.go('/bosses/${widget.bossId}/call'));
      return;
    }
    _scheduleNext(story);
  }

  /// 다음 메시지 예약 — 친구 차례면 타이핑 인디케이터를 먼저 보여준다.
  void _scheduleNext(IntroStory story) {
    if (_visible >= story.messages.length) {
      _timer = Timer(_finalDelay, () {
        if (mounted) setState(() => _showFinal = true);
      });
      return;
    }
    final next = story.messages[_visible];
    final friendNext = next.kind == IntroMessageKind.friend ||
        next.kind == IntroMessageKind.friendPhoto;
    if (friendNext && !_typing) {
      _timer = Timer(_typingLead, () {
        if (!mounted) return;
        setState(() => _typing = true);
        _timer = Timer(_typingHold, () {
          if (!mounted) return;
          setState(() {
            _typing = false;
            _visible++;
          });
          SoundService.instance.chat(); // 상대(친구) 메시지 도착음
          _scheduleNext(story);
        });
      });
    } else {
      _timer = Timer(_visible == 0 ? _firstDelay : _messageGap, () {
        if (!mounted) return;
        setState(() => _visible++);
        _scheduleNext(story);
      });
    }
  }

  void _skipOrCall() => context.go('/bosses/${widget.bossId}/call');

  @override
  void dispose() {
    _timer?.cancel();
    _loop.dispose();
    SoundService.instance.unsuppressBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boss = _boss;
    final story = _story;
    if (boss == null || story == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final phone = _phoneBody(boss, story);
    if (isDesktop(context)) {
      return Scaffold(
        backgroundColor: YbsColor.bgApp,
        body: Column(
          children: [
            _desktopTopBar(boss),
            Expanded(child: Center(child: _phoneStage(phone))),
          ],
        ),
      );
    }
    return Scaffold(body: SafeArea(bottom: false, child: phone));
  }

  // ============================================================ 데스크톱 스테이지
  Widget _desktopTopBar(Boss boss) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
      decoration: const BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border(bottom: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: YbsColor.gold500),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: Text(
                'MISSION No.${boss.number.toString().padLeft(3, '0')} · 인트로',
                style: const TextStyle(
                    fontFamily: YbsType.numeric,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: YbsColor.gold400)),
          ),
          const SizedBox(width: 14),
          const Text('전화를 걸어야 하는 이유 — 스토리 재생 중',
              style: TextStyle(fontSize: 13, color: YbsColor.textSub)),
          const Spacer(),
          GestureDetector(
            onTap: _skipOrCall,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.md),
              ),
              child: const Text('건너뛰기',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: YbsColor.textSub)),
            ),
          ),
        ],
      ),
    );
  }

  /// 인콜과 동일한 폰 스테이지 — 통화 화면과 같은 [PhoneFrame](390px) 재사용
  /// (디자인 2a: "인콜과 동일한 폰 스테이지 처리").
  Widget _phoneStage(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: YbsSpace.s5),
      child: PhoneFrame(child: child),
    );
  }

  // ================================================================ phone body
  Widget _phoneBody(Boss boss, IntroStory story) {
    return Container(
      color: YbsColor.bgApp,
      child: Column(
        children: [
          _header(boss, story),
          Expanded(child: _messageList(story)),
          if (!_showFinal) _midBar(),
        ],
      ),
    );
  }

  Widget _header(Boss boss, IntroStory story) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: const Border(bottom: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/bosses/${boss.id}'),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: YbsColor.textSub),
          ),
          const SizedBox(width: 12),
          _avatar(story, size: 36, fontSize: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(story.friendName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: YbsColor.textHero)),
                Text(story.contextLabel,
                    style: const TextStyle(
                        fontSize: 11, color: YbsColor.textFaint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: YbsColor.gold500),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: Text(
                'STORY · No.${boss.number.toString().padLeft(3, '0')}',
                style: const TextStyle(
                    fontFamily: YbsType.numeric,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: YbsColor.gold400)),
          ),
        ],
      ),
    );
  }

  Widget _avatar(IntroStory story, {required double size, required double fontSize}) =>
      _avatarFor(story.friendName, size: size, fontSize: fontSize);

  /// 이름 첫 글자 아바타 — 발신자별(친구·교수님 등) 구분에 사용.
  Widget _avatarFor(String name, {required double size, required double fontSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: YbsColor.surfaceInset,
        border: Border.all(color: YbsColor.borderStrong),
        gradient: RadialGradient(
          center: const Alignment(0, -0.24),
          radius: 0.7,
          colors: [YbsColor.sky400.withValues(alpha: 0.22), Colors.transparent],
        ),
      ),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '?' : name.characters.first,
          style: TextStyle(
              fontFamily: YbsType.display,
              fontSize: fontSize,
              height: 1,
              color: YbsColor.sky400)),
    );
  }

  // ================================================================ 메시지 목록
  Widget _messageList(IntroStory story) {
    final shown = story.messages.take(_visible).toList();
    final rows = <Widget>[
      Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: YbsColor.surfaceInset,
            borderRadius: BorderRadius.circular(YbsRadius.full),
          ),
          child: Text(story.timeCapsule,
              style:
                  const TextStyle(fontSize: 11, color: YbsColor.textFaint)),
        ),
      ),
      for (var i = 0; i < shown.length; i++)
        _arrive(
          animate: i == shown.length - 1 && !_typing && !_showFinal,
          child: _bubble(story, shown[i]),
        ),
      if (_typing) _arrive(animate: true, child: _typingBubble(story)),
      if (_showFinal) ...[
        _incomingDivider(),
        _arrive(animate: true, child: _callCard(story)),
      ],
    ];
    // 하단 정렬 + 넘치면 위로 스크롤 (디자인: justify-content flex-end).
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// 도착 애니메이션 (디자인 intro-arrive: 아래서 살짝 떠오르며 등장).
  Widget _arrive({required bool animate, required Widget child}) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: c),
        ),
      ),
      child: child,
    );
  }

  Widget _bubble(IntroStory story, IntroMessage m) {
    switch (m.kind) {
      case IntroMessageKind.mine:
        return _mineRow(m.time,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: YbsColor.go500,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(m.text,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: YbsColor.textOnGo)),
            ));
      case IntroMessageKind.minePhoto:
        return _mineRow(m.time,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: YbsColor.go500,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: _photoPlaceholder(m, mine: true),
            ));
      case IntroMessageKind.friend:
        return _friendRow(story, m.time, senderName: m.senderName,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(m.text,
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.5, color: YbsColor.textBody)),
            ));
      case IntroMessageKind.friendPhoto:
        return _friendRow(story, m.time, senderName: m.senderName,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: _photoPlaceholder(m, mine: false),
            ));
      case IntroMessageKind.system:
        return Center(
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.borderStrong),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: YbsColor.live500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Text('알',
                            style: TextStyle(
                                fontFamily: YbsType.display,
                                fontSize: 11,
                                height: 1,
                                color: YbsColor.white)),
                      ),
                      const SizedBox(width: 8),
                      const Text('자동 알림',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: YbsColor.textSub)),
                      const Spacer(),
                      Text(m.time,
                          style: const TextStyle(
                              fontSize: 10, color: YbsColor.textFaint)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(m.text,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: YbsColor.textBody)),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _mineRow(String time, {required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(time,
            style: const TextStyle(fontSize: 10, color: YbsColor.textFaint)),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: child,
        ),
      ],
    );
  }

  Widget _friendRow(IntroStory story, String time,
      {required Widget child, String? senderName}) {
    final name = senderName ?? story.friendName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatarFor(name, size: 30, fontSize: 12),
        const SizedBox(width: 8),
        // avatar+시간 라벨이 차지하는 폭을 뺀 나머지에만 맞도록 Flexible로
        // 감싸지 않으면, 말풍선+시간 텍스트 합이 남은 폭을 미세하게 넘길 때
        // RenderFlex 오버플로가 난다 (2026-07-14 확인).
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 11, color: YbsColor.textFaint)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: child,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 10, color: YbsColor.textFaint)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder(IntroMessage m, {required bool mine}) {
    final fg = mine ? YbsColor.textOnGo : YbsColor.textFaint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 200,
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: mine
                  ? const [Color(0xFF232936), Color(0xFF171C26), Color(0xFF10141C)]
                  : const [Color(0xFF1B2634), Color(0xFF141B26), Color(0xFF0F141D)],
            ),
          ),
          child: m.imageAsset != null
              ? Image.asset(m.imageAsset!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined,
                        size: 26,
                        color: mine
                            ? const Color(0xFF9AA6B8)
                            : YbsColor.sky400.withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    Text(m.caption,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9AA6B8))),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.file,
                  style: TextStyle(
                      fontFamily: YbsType.numeric,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.75))),
              Text('사진',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: 0.75))),
            ],
          ),
        ),
      ],
    );
  }

  /// 타이핑 인디케이터 — 점 3개가 시차를 두고 튀어오른다 (intro-dot).
  Widget _typingBubble(IntroStory story) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _avatar(story, size: 30, fontSize: 12),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: YbsColor.surfaceCard,
            border: Border.all(color: YbsColor.borderSoft),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  _typingDot(i),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _typingDot(int index) {
    // 0~1 루프에서 점별 위상차 — 30% 지점에 -4px 피크 (디자인 intro-dot).
    final t = (_loop.value - index * 0.136) % 1.0;
    final lift = t < 0.3
        ? (t / 0.3)
        : t < 0.6
            ? (1 - (t - 0.3) / 0.3)
            : 0.0;
    return Transform.translate(
      offset: Offset(0, -4 * lift),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: YbsColor.textFaint.withValues(alpha: 0.4 + 0.6 * lift),
        ),
      ),
    );
  }

  // ================================================================ 발신 카드
  Widget _incomingDivider() {
    final incoming = _story?.incoming ?? false;
    return Row(
      children: [
        const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(incoming ? 'INCOMING CALL' : 'OUTGOING CALL',
              style: TextStyle(
                  fontFamily: YbsType.numeric,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: YbsColor.live400)),
        ),
        const Expanded(child: Divider(color: YbsColor.borderStrong, height: 1)),
      ],
    );
  }

  Widget _callCard(IntroStory story) {
    final incoming = story.incoming;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.live600),
        borderRadius: BorderRadius.circular(20),
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.1,
          colors: [
            YbsColor.live500.withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: YbsColor.live500.withValues(alpha: 0.14), blurRadius: 28),
        ],
      ),
      child: Column(
        children: [
          Text(incoming ? '전화가 왔어요' : story.callCardTitle,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: YbsColor.textSub)),
          const SizedBox(height: 12),
          Text(incoming ? story.callCardTitle : story.phoneNumber,
              style: TextStyle(
                  fontFamily: incoming ? YbsType.display : YbsType.numeric,
                  fontSize: incoming ? 26 : 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: incoming ? 0 : 1.2,
                  height: 1.1,
                  color: YbsColor.textHero)),
          const SizedBox(height: 12),
          Text(incoming ? '지금 수신 중…' : '상담 가능 시간 · 지금',
              style: const TextStyle(fontSize: 12, color: YbsColor.textFaint)),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _loop,
            builder: (context, child) {
              // 발신 버튼 글로우 펄스 (ybs-ring-go 대응).
              final pulse = 0.5 + 0.5 * (1 - (2 * _loop.value - 1).abs());
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: YbsColor.go500
                            .withValues(alpha: 0.2 + 0.25 * pulse),
                        blurRadius: 18 + 14 * pulse),
                  ],
                ),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _skipOrCall,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: YbsColor.go500,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.call, size: 21, color: YbsColor.textOnGo),
                    const SizedBox(width: 10),
                    Text(incoming ? '전화 받기' : '전화 걸기',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: YbsColor.textOnGo)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('연결되면 보스전이 시작돼요 · 제한 시간 ${_limit(_boss!)}',
              style:
                  const TextStyle(fontSize: 11.5, color: YbsColor.textFaint)),
        ],
      ),
    );
  }

  String _limit(Boss boss) {
    final mm = boss.timeLimit.inMinutes.toString().padLeft(2, '0');
    final ss = (boss.timeLimit.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ================================================================ 하단 바
  Widget _midBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: const Border(top: BorderSide(color: YbsColor.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: YbsColor.surfaceInset,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: const Text('이야기가 진행 중이에요…',
                  style:
                      TextStyle(fontSize: 13, color: YbsColor.textFaint)),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _skipOrCall,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: YbsColor.surfaceCard,
                border: Border.all(color: YbsColor.borderSoft),
                borderRadius: BorderRadius.circular(YbsRadius.full),
              ),
              child: const Text('건너뛰기',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: YbsColor.textSub)),
            ),
          ),
        ],
      ),
    );
  }
}
