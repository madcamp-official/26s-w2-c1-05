import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../platform/stt_factory.dart';
import '../../ui/breakpoints.dart';
import '../../ui/theme.dart';

/// 0. 온보딩 (IA 0.1 소개 → 0.2 마이크 권한+STT 준비 → 0.3 닉네임).
/// 닉네임 저장 등 영속화는 미구현 — 화면 플로우만. STT 준비 버튼은 실제
/// 권한 요청(SttEngine.initialize)을 수행한다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  bool? _sttReady; // null = 미확인
  final _nickname = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _checkStt() async {
    final ok = await createSttEngine().initialize();
    if (mounted) setState(() => _sttReady = ok);
  }

  void _next() {
    if (_index < 2) {
      _page.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _page,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [_intro(), _micSetup(), _nicknamePage()],
                  ),
                ),
                _dots(),
                Padding(
                  padding: const EdgeInsets.all(YbsSpace.s5),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: YbsColor.go500,
                        foregroundColor: YbsColor.textOnGo,
                        minimumSize: const Size.fromHeight(YbsSpace.hitCall - 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YbsRadius.md)),
                      ),
                      onPressed: _next,
                      child: Text(_index == 2 ? '시작하기' : '다음',
                          style: const TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: i == _index ? 20 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _index ? YbsColor.go500 : YbsColor.ink600,
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
          ),
      ],
    );
  }

  // ---- 0.1 소개 ----
  Widget _intro() {
    Widget feature(IconData icon, Color color, String title, String desc) => Padding(
          padding: const EdgeInsets.only(bottom: YbsSpace.s4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(YbsRadius.sm),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: YbsSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: YbsType.bodyMd, fontWeight: FontWeight.w700, color: YbsColor.textHero)),
                    Text(desc, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(YbsSpace.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('여보세요',
              style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.poster, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          const Text('전화가 무서운 당신을 위한\n실전 트레이닝 게임',
              style: TextStyle(fontSize: YbsType.bodyLg, height: 1.4, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s10),
          feature(Icons.sports_kabaddi, YbsColor.live400, '전화 보스전', 'AI 진상 보스와 통화로 맞붙어요'),
          feature(Icons.bolt, YbsColor.go400, '실시간 전화 배틀', '다른 유저와 1:1 민원 대결'),
          feature(Icons.receipt_long, YbsColor.gold400, '말하기 리포트', '판이 끝나면 AI가 화법을 코칭'),
        ],
      ),
    );
  }

  // ---- 0.2 마이크 권한 + STT 준비 ----
  Widget _micSetup() {
    final desktop = isDesktop(context);
    final (statusText, statusColor) = switch (_sttReady) {
      null => ('아래 버튼을 눌러 준비 상태를 확인하세요', YbsColor.textFaint),
      true => ('준비 완료! 음성 인식을 쓸 수 있어요', YbsColor.go400),
      false => ('음성 인식 불가 — 통화에서 텍스트 입력으로 진행돼요', YbsColor.amber400),
    };
    return Padding(
      padding: const EdgeInsets.all(YbsSpace.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(desktop ? '서버 음성 인식 연결' : '마이크 준비',
              style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          Text(
            desktop ? '데스크톱은 서버 STT를 사용해요.\n연결 상태를 확인할게요.' : '통화는 음성으로 진행돼요.\n마이크 권한이 필요해요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textSub),
          ),
          const SizedBox(height: YbsSpace.s10),
          GestureDetector(
            onTap: _checkStt,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: YbsColor.go500.withValues(alpha: 0.10),
                border: Border.all(color: _sttReady == false ? YbsColor.amber400 : YbsColor.go600, width: 2),
                boxShadow: [BoxShadow(color: YbsColor.goGlow, blurRadius: 30)],
              ),
              child: Icon(
                _sttReady == true ? Icons.check : Icons.mic,
                size: 40,
                color: _sttReady == false ? YbsColor.amber400 : YbsColor.go400,
              ),
            ),
          ),
          const SizedBox(height: YbsSpace.s5),
          Text(statusText, textAlign: TextAlign.center, style: TextStyle(fontSize: YbsType.sub, color: statusColor)),
        ],
      ),
    );
  }

  // ---- 0.3 닉네임 ----
  Widget _nicknamePage() {
    return Padding(
      padding: const EdgeInsets.all(YbsSpace.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('뭐라고 불러드릴까요?',
              style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, color: YbsColor.textHero)),
          const SizedBox(height: YbsSpace.s2),
          const Text('배틀 상대와 랭킹에 표시될 이름이에요.',
              style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
          const SizedBox(height: YbsSpace.s8),
          TextField(
            controller: _nickname,
            maxLength: 12,
            style: const TextStyle(fontSize: YbsType.bodyLg, color: YbsColor.textHero),
            decoration: InputDecoration(
              hintText: '예: 환불전사_수원',
              hintStyle: const TextStyle(color: YbsColor.textFaint),
              counterStyle: const TextStyle(color: YbsColor.textFaint),
              filled: true,
              fillColor: YbsColor.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(YbsRadius.md),
                borderSide: const BorderSide(color: YbsColor.borderSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
