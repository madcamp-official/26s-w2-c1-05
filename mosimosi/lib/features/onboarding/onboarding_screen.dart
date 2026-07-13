import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../platform/stt_factory.dart';
import '../../services/auth_service.dart';
import '../../services/game_server_client.dart';
import '../../ui/breakpoints.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// 0. 온보딩 (4단계): 컨셉 → 마이크 권한 → 소셜 로그인 → 닉네임.
/// 로그인(Google/Kakao)은 브라우저 OAuth(AuthService) — 기존 계정이면 닉네임
/// 단계 없이 홈으로, 신규면 닉네임을 PATCH /users/me로 설정.
/// 재진입(설정 '온보딩 다시 보기') 시 로그인 단계는 통과, 닉네임은 변경 가능.
/// '마이크 허용'은 실제 권한 요청(SttEngine.initialize)을 수행하고,
/// 데스크톱 2단계는 연결 체크리스트 표시.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  bool? _sttReady; // null = 미확인
  late final TextEditingController _nickname =
      TextEditingController(text: LocalStore.instance.nickname ?? '민준');
  bool _submitting = false;
  String? _nicknameError;
  bool _signingIn = false;
  String? _loginError;
  bool _localMode = false; // 로그인 단계: false=소셜 버튼, true=이메일 폼
  bool _isSignup = true; // 이메일 폼: 가입 ↔ 로그인 토글
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  void _next() =>
      _page.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  /// 소셜 로그인 (3/4) — 성공 시 기존 계정은 홈으로, 신규는 닉네임 단계로.
  Future<void> _signIn(String provider) async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _loginError = null;
    });
    try {
      final res = await AuthService().signIn(provider);
      await LocalStore.instance.saveAuth(
          token: res.token, userId: res.userId, nickname: res.nickname);
      if (!mounted) return;
      if (res.nickname != null) {
        context.go('/home'); // 기존 계정 — 온보딩 생략
      } else {
        _next();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _loginError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loginError = '서버에 연결할 수 없어요 — 네트워크를 확인해 주세요');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  /// 이메일 가입/로그인 (3/4) — 성공 처리는 소셜과 동일.
  Future<void> _submitLocal() async {
    if (_signingIn) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _loginError = '이메일 형식을 확인해 주세요');
      return;
    }
    if (password.length < 8) {
      setState(() => _loginError = '비밀번호는 8자 이상이어야 해요');
      return;
    }
    if (_isSignup && password != _password2.text) {
      setState(() => _loginError = '비밀번호가 서로 달라요');
      return;
    }
    setState(() {
      _signingIn = true;
      _loginError = null;
    });
    try {
      final auth = AuthService();
      final res = _isSignup
          ? await auth.signUpLocal(email: email, password: password)
          : await auth.signInLocal(email: email, password: password);
      await LocalStore.instance.saveAuth(
          token: res.token, userId: res.userId, nickname: res.nickname);
      if (!mounted) return;
      if (res.nickname != null) {
        context.go('/home');
      } else {
        _next();
      }
    } on GameServerException catch (e) {
      if (mounted) {
        setState(() => _loginError = switch (e.statusCode) {
              409 => '이미 가입된 이메일이에요 — 아래에서 로그인으로 바꿔 보세요',
              401 => '이메일 또는 비밀번호가 올바르지 않아요',
              422 => '입력값을 확인해 주세요',
              _ => '서버 오류 — 잠시 후 다시 시도해 주세요',
            });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loginError = '서버에 연결할 수 없어요 — 네트워크를 확인해 주세요');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  /// 닉네임 확정 (4/4) → PATCH /users/me → 첫 보스 브리핑으로.
  Future<void> _submitNickname() async {
    if (_submitting) return;
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      setState(() => _nicknameError = '닉네임을 입력해 주세요');
      return;
    }
    // 재진입 + 변경 없음 — 서버 호출 없이 통과.
    if (nickname == LocalStore.instance.nickname) {
      context.go('/bosses/chicken');
      return;
    }
    setState(() {
      _submitting = true;
      _nicknameError = null;
    });
    try {
      final res = await GameServerClient()
          .patchJson('/users/me', {'nickname': nickname});
      await LocalStore.instance.saveNickname(res['nickname'] as String);
      if (mounted) context.go('/bosses/chicken');
    } on GameServerException catch (e) {
      if (mounted) {
        setState(() => _nicknameError =
            e.statusCode == 409 ? '이미 사용 중인 닉네임이에요' : '서버 오류 — 잠시 후 다시 시도해 주세요');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _nicknameError = '서버에 연결할 수 없어요 — 네트워크를 확인해 주세요');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
              // 로그인(3/4) 없이 스와이프로 닉네임 단계에 가는 것 방지 — 버튼 진행만.
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [_concept(), _micPage(), _loginPage(), _nicknamePage()],
            ),
          ),
        ),
      ),
    );
  }

  // ---- 공통 하단 (dots + CTA) ----
  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
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
      );

  Widget _footer({String? cta, VoidCallback? onTap, String? caption}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(YbsSpace.s6, 0, YbsSpace.s6, 30),
      child: Column(
        children: [
          _dots(),
          if (cta != null) ...[
            const SizedBox(height: YbsSpace.s4),
            YbsButton(label: cta, size: YbsButtonSize.lg, fullWidth: true, onTap: onTap),
          ],
          if (caption != null) ...[
            const SizedBox(height: YbsSpace.s2 + 2),
            Text(caption, style: const TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
          ],
        ],
      ),
    );
  }

  /// 공간이 충분하면 기존처럼 채우고(Expanded 유지), 키보드 등으로 줄어들면
  /// 넘치는 대신 스크롤되게 함. IntrinsicHeight가 Expanded의 실제 높이를
  /// 재보고 그만큼을 ConstrainedBox(minHeight)에 전달하는 표준 패턴.
  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
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
      child: _scrollable(Column(
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
      )),
    );
  }

  // ---- 2/3 마이크 권한 (+데스크톱 STT 체크) ----
  Widget _micPage() {
    final desktop = isDesktop(context);
    return _scrollable(Column(
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
    ));
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

  // ---- 3/4 소셜 로그인 ----
  Widget _loginPage() {
    final store = LocalStore.instance;
    final loggedIn = store.hasUser;
    return _scrollable(Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _heroCircle(
                      icon: Icons.person_outline,
                      accent: YbsColor.gold400,
                      border: YbsColor.borderStrong),
                ),
                const SizedBox(height: YbsSpace.s6),
                const Text('계정으로 기록을 지켜요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: YbsType.display,
                        fontSize: YbsType.displaySize,
                        height: 1.25,
                        color: YbsColor.white)),
                const SizedBox(height: YbsSpace.s3),
                Text(
                    loggedIn
                        ? '이미 ${store.nickname ?? '계정'}으로 로그인돼 있어요'
                        : _localMode
                            ? (_isSignup ? '이메일과 비밀번호로 가입해요' : '가입했던 이메일로 로그인해요')
                            : '전적·도감·랭킹을 어느 기기에서든 이어가요.\n브라우저가 열리면 로그인해 주세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, height: 1.6, color: YbsColor.textSub)),
                if (!loggedIn && !_localMode) ...[
                  const SizedBox(height: YbsSpace.s6),
                  YbsButton(
                    label: _signingIn ? '브라우저에서 로그인 중…' : 'Google로 계속하기',
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: _signingIn ? null : () => _signIn('google'),
                  ),
                  const SizedBox(height: YbsSpace.s3),
                  YbsButton(
                    label: _signingIn ? '브라우저에서 로그인 중…' : '카카오로 계속하기',
                    variant: YbsButtonVariant.secondary,
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: _signingIn ? null : () => _signIn('kakao'),
                  ),
                  const SizedBox(height: YbsSpace.s3),
                  YbsButton(
                    label: '이메일로 계속하기',
                    variant: YbsButtonVariant.ghost,
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: _signingIn
                        ? null
                        : () => setState(() {
                              _localMode = true;
                              _loginError = null;
                            }),
                  ),
                ],
                if (!loggedIn && _localMode) ...[
                  const SizedBox(height: YbsSpace.s6),
                  _authField(_email, '이메일',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: YbsSpace.s3),
                  _authField(_password, '비밀번호 (8자 이상)', obscure: true),
                  if (_isSignup) ...[
                    const SizedBox(height: YbsSpace.s3),
                    _authField(_password2, '비밀번호 확인', obscure: true),
                  ],
                  const SizedBox(height: YbsSpace.s5),
                  YbsButton(
                    label: _signingIn ? '처리 중…' : (_isSignup ? '가입하기' : '로그인'),
                    size: YbsButtonSize.lg,
                    fullWidth: true,
                    onTap: _signingIn ? null : _submitLocal,
                  ),
                  const SizedBox(height: YbsSpace.s2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _signingIn
                            ? null
                            : () => setState(() {
                                  _isSignup = !_isSignup;
                                  _loginError = null;
                                }),
                        child: Text(
                            _isSignup ? '이미 계정이 있어요 — 로그인' : '계정이 없어요 — 가입',
                            style: const TextStyle(
                                fontSize: YbsType.micro,
                                color: YbsColor.go400)),
                      ),
                      TextButton(
                        onPressed: _signingIn
                            ? null
                            : () => setState(() {
                                  _localMode = false;
                                  _loginError = null;
                                }),
                        child: const Text('소셜 로그인으로',
                            style: TextStyle(
                                fontSize: YbsType.micro,
                                color: YbsColor.textSub)),
                      ),
                    ],
                  ),
                ],
                if (_loginError != null) ...[
                  const SizedBox(height: YbsSpace.s3),
                  Text(_loginError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: YbsType.micro, color: YbsColor.live400)),
                ],
              ],
            ),
          ),
        ),
        if (loggedIn)
          _footer(cta: '다음', onTap: _next)
        else
          _footer(caption: '이메일은 계정 식별에만 쓰여요 — 비밀번호는 만들지 않아요'),
      ],
    ));
  }

  Widget _authField(TextEditingController controller, String hint,
      {bool obscure = false, TextInputType? keyboardType}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: YbsColor.surfaceInset,
        border: Border.all(color: YbsColor.borderSoft),
        borderRadius: BorderRadius.circular(YbsRadius.lg - 4),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(
              fontSize: YbsType.sub, color: YbsColor.textHero),
          cursorColor: YbsColor.go400,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: YbsType.sub, color: YbsColor.textFaint),
          ),
        ),
      ),
    );
  }

  // ---- 4/4 닉네임 ----
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

    return _scrollable(Column(
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
                Text(_nicknameError ?? '배틀과 랭킹에서 쓸 이름이에요',
                    style: TextStyle(
                        fontSize: YbsType.micro,
                        color: _nicknameError == null ? YbsColor.go400 : YbsColor.live400)),
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
        _footer(
            cta: _submitting ? '계정 만드는 중…' : '첫 보스에게 전화 걸기',
            onTap: _submitNickname),
      ],
    ));
  }
}
