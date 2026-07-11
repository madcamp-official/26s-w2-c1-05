import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../platform/stt_factory.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 0. 온보딩 (3단계) — 디자인 K 섹션 이식: 컨셉 → 마이크 권한 → 닉네임.
/// 닉네임 저장 등 영속화는 미구현. '마이크 허용'은 실제 권한 요청
/// (SttEngine.initialize)을 수행하고, 데스크톱 2단계는 연결 체크리스트 표시.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  bool? _sttReady; // null = 미확인
  final _nickname = TextEditingController(text: '민준');

  @override
  void dispose() {
    _page.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _next() =>
      _page.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  Future<void> _requestMic() async {
    final ok = await createSttEngine().initialize();
    if (!mounted) return;
    setState(() => _sttReady = ok);
    _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              children: [_concept(), _micPage(), _nicknamePage()],
            ),
          ),
        ),
      ),
    );
  }

  // ---- 공통 하단 (dots + CTA) ----
  Widget _footer({required String cta, required VoidCallback onTap, String? caption}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s6, 0, YbsSpace.s6, 30),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: i == _index ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _index ? YbsColor.go500 : YbsColor.ink600,
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                  ),
                ),
            ],
          ),
          const SizedBox(height: YbsSpace.s4),
          YbsButton(label: cta, size: YbsButtonSize.lg, fullWidth: true, onTap: onTap),
          if (caption != null) ...[
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(caption, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
          ],
        ],
      ),
    );
  }

  Widget _heroCircle({required IconData icon, required Color accent, required Color border}) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: YbsColor.surfaceInset,
        gradient: RadialGradient(
          center: const Alignment(0, -0.24),
          radius: 0.72,
          colors: [accent.withValues(alpha: 0.25), Colors.transparent],
        ),
        border: Border.all(color: border, width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 28)],
      ),
      child: Icon(icon, size: 40, color: accent),
    );
  }

  // ---- 1/3 컨셉 ----
  Widget _concept() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 0.9,
          colors: [YbsColor.live500.withValues(alpha: 0.10), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _heroCircle(icon: Icons.call, accent: YbsColor.live400, border: YbsColor.live600),
                const SizedBox(height: YbsSpace.s6),
                const Text('전화가 무서운 건\n당신 탓이 아니에요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: YbsType.display, fontSize: 38, height: 1.2, color: YbsColor.white)),
                const SizedBox(height: YbsSpace.s3),
                const Text('AI 진상 보스에게 전화를 걸어\n게임처럼 연습하세요. 진짜 전화는 아니에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.6, color: YbsColor.textSub)),
              ],
            ),
          ),
          _footer(cta: '시작하기', onTap: _next),
        ],
      ),
    );
  }

  // ---- 2/3 마이크 권한 (+데스크톱 STT 체크) ----
  Widget _micPage() {
    final desktop = isDesktop(context);
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _heroCircle(icon: Icons.mic, accent: YbsColor.go400, border: YbsColor.go600),
              const SizedBox(height: YbsSpace.s6),
              Text(desktop ? '목소리가 게임 컨트롤러예요' : '목소리가\n게임 컨트롤러예요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.25, color: YbsColor.white)),
              const SizedBox(height: YbsSpace.s3),
              const Text('통화 연습에 마이크가 필요해요.\n녹음은 리포트 생성에만 쓰고 바로 지워요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.6, color: YbsColor.textSub)),
              if (desktop) ...[
                const SizedBox(height: YbsSpace.s6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
                  child: _desktopCheckCard(),
                ),
              ],
            ],
          ),
        ),
        _footer(cta: desktop ? '다음' : '마이크 허용', onTap: _requestMic, caption: '설정에서 언제든 바꿀 수 있어요'),
      ],
    );
  }

  Widget _desktopCheckCard() {
    Widget row(bool? ok, String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(bottom: YbsSpace.s3 + 2),
          child: Row(children: [
            if (ok == true)
              const Icon(Icons.check, size: 18, color: YbsColor.go400)
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: YbsColor.ink500, width: 2)),
              ),
            const SizedBox(width: YbsSpace.s3),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: YbsType.sub, color: ok == true ? YbsColor.textBody : YbsColor.textSub)),
            ),
            ?trailing,
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s5, YbsSpace.s4 + 2, YbsSpace.s5, YbsSpace.s1),
      decoration: BoxDecoration(
        color: YbsColor.surfaceCard,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
      ),
      child: Column(children: [
        row(_sttReady, '마이크 감지 ${_sttReady == null ? "— 아래 버튼으로 확인" : _sttReady! ? "됨" : "실패"}'),
        row(_sttReady, '음성 인식 서버 연결${_sttReady == true ? "됨" : " 확인 대기"}',
            trailing: _sttReady == true
                ? const Text('OK',
                    style: TextStyle(fontFamily: YbsType.numeric, fontSize: YbsType.micro, fontWeight: FontWeight.w600, color: YbsColor.go400))
                : null),
        row(null, '「여보세요」라고 말해 보세요 — 인식 테스트'),
      ]),
    );
  }

  // ---- 3/3 닉네임 ----
  Widget _nicknamePage() {
    Widget chip(String label) => GestureDetector(
          onTap: () => setState(() => _nickname.text = label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: YbsColor.borderSoft),
              borderRadius: BorderRadius.circular(YbsRadius.full),
            ),
            child: Text(label, style: const TextStyle(fontSize: 13, color: YbsColor.textSub)),
          ),
        );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('뭐라고 부를까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.displaySize, height: 1.25, color: YbsColor.white)),
                const SizedBox(height: YbsSpace.s3),
                const Text('배틀에서 상대에게 보여지는 이름이에요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.6, color: YbsColor.textSub)),
                const SizedBox(height: YbsSpace.s6),
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: YbsColor.surfaceInset,
                    border: Border.all(color: YbsColor.go600),
                    borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
                    boxShadow: [BoxShadow(color: YbsColor.go500.withValues(alpha: 0.10), blurRadius: 16)],
                  ),
                  child: Center(
                    child: TextField(
                      controller: _nickname,
                      maxLength: 12,
                      style: const TextStyle(fontSize: YbsType.bodyLg, fontWeight: FontWeight.w700, color: YbsColor.textHero),
                      cursorColor: YbsColor.go400,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: YbsSpace.s2 + 2),
                const Text('사용할 수 있는 이름이에요', style: TextStyle(fontSize: YbsType.micro, color: YbsColor.go400)),
                const SizedBox(height: YbsSpace.s5),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: YbsSpace.s2,
                  runSpacing: YbsSpace.s2,
                  children: [chip('환불전사'), chip('통화의신'), chip('여보세요고수')],
                ),
              ],
            ),
          ),
        ),
        _footer(cta: '첫 보스에게 전화 걸기', onTap: () => context.go('/bosses/chicken')),
      ],
    );
  }
}
