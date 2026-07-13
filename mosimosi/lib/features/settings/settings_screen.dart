import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../services/game_server_client.dart';
import '../../ui/theme.dart';

/// 6. 설정 — 프로필(닉네임 변경)·계정(로그아웃/탈퇴)/마이크 테스트/음성 설정/
/// 데이터 안내 (IA §3). TTS 속도·턴 감지는 로컬 상태 데모.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _ttsRate = 0.5;
  bool _autoTurn = false;
  String? _accountLabel; // '{email} · Google' — GET /users/me 성공 시

  @override
  void initState() {
    super.initState();
    if (LocalStore.instance.hasUser) {
      GameServerClient().getJson('/users/me').then((me) {
        if (!mounted) return;
        final provider = switch (me['provider']) {
          'kakao' => 'Kakao',
          'local' => '이메일',
          _ => 'Google',
        };
        final email = me['email'] as String?;
        setState(() => _accountLabel =
            email == null ? provider : '$email · $provider');
      }).catchError((_) {}); // 오프라인 등 — 표기만 생략
    }
  }

  /// 닉네임 변경 — PATCH /users/me (409 = 중복).
  Future<void> _editNickname() async {
    final controller =
        TextEditingController(text: LocalStore.instance.nickname);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? error;
        bool saving = false;
        return StatefulBuilder(builder: (ctx, setDialog) {
          Future<void> save() async {
            final nickname = controller.text.trim();
            if (nickname.isEmpty) {
              setDialog(() => error = '닉네임을 입력해 주세요');
              return;
            }
            if (nickname == LocalStore.instance.nickname) {
              Navigator.pop(ctx);
              return;
            }
            setDialog(() {
              saving = true;
              error = null;
            });
            try {
              final res = await GameServerClient()
                  .patchJson('/users/me', {'nickname': nickname});
              await LocalStore.instance
                  .saveNickname(res['nickname'] as String);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            } on GameServerException catch (e) {
              setDialog(() {
                saving = false;
                error = e.statusCode == 409
                    ? '이미 사용 중인 닉네임이에요'
                    : '서버 오류 — 잠시 후 다시 시도해 주세요';
              });
            } catch (_) {
              setDialog(() {
                saving = false;
                error = '서버에 연결할 수 없어요';
              });
            }
          }

          return AlertDialog(
            backgroundColor: YbsColor.surfaceCard,
            title: const Text('닉네임 변경',
                style: TextStyle(
                    fontFamily: YbsType.display,
                    fontSize: YbsType.bodyLg,
                    color: YbsColor.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLength: 12,
                  autofocus: true,
                  style: const TextStyle(color: YbsColor.textHero),
                  cursorColor: YbsColor.go400,
                ),
                if (error != null)
                  Text(error!,
                      style: const TextStyle(
                          fontSize: YbsType.micro, color: YbsColor.live400)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소',
                    style: TextStyle(color: YbsColor.textSub)),
              ),
              TextButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '저장 중…' : '저장',
                    style: const TextStyle(color: YbsColor.go400)),
              ),
            ],
          );
        });
      },
    );
    controller.dispose();
  }

  Future<bool> _confirm(String title, String message, String cta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YbsColor.surfaceCard,
        title: Text(title,
            style: const TextStyle(
                fontFamily: YbsType.display,
                fontSize: YbsType.bodyLg,
                color: YbsColor.white)),
        content: Text(message,
            style: const TextStyle(
                fontSize: YbsType.sub, height: 1.5, color: YbsColor.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: YbsColor.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cta, style: const TextStyle(color: YbsColor.live400)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _logout() async {
    if (!await _confirm('로그아웃', '로그아웃할까요? 같은 계정으로 다시 로그인하면 기록이 유지돼요.', '로그아웃')) {
      return;
    }
    await LocalStore.instance.clearAuth();
    if (mounted) context.go('/onboarding');
  }

  Future<void> _deleteAccount() async {
    if (!await _confirm(
        '회원 탈퇴', '정말 탈퇴할까요? 전적·도감 진행이 모두 삭제되고 되돌릴 수 없어요.', '탈퇴')) {
      return;
    }
    try {
      await GameServerClient().deleteJson('/users/me');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('탈퇴에 실패했어요 — 잠시 후 다시 시도해 주세요')));
      }
      return;
    }
    await LocalStore.instance.clearAuth();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('설정', style: TextStyle(fontFamily: YbsType.display, fontSize: YbsType.bodyLg)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(YbsSpace.s5),
          children: [
            _section('프로필'),
            _card([
              _row(
                icon: Icons.badge_outlined,
                title: '닉네임',
                onTap: _editNickname,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(LocalStore.instance.nickname ?? '미설정',
                      style: const TextStyle(
                          fontSize: YbsType.sub, color: YbsColor.textSub)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: YbsColor.textFaint),
                ]),
              ),
              if (_accountLabel != null) ...[
                const Divider(height: 1, color: YbsColor.borderSoft),
                _row(
                  icon: Icons.alternate_email,
                  title: '로그인 계정',
                  trailing: Text(_accountLabel!,
                      style: const TextStyle(
                          fontSize: YbsType.micro, color: YbsColor.textSub)),
                ),
              ],
            ]),
            _section('음성'),
            _card([
              _row(
                icon: Icons.mic_none,
                title: '마이크 테스트',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: YbsSpace.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: YbsColor.go500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(YbsRadius.full),
                    border: Border.all(color: YbsColor.go600),
                  ),
                  child: const Text('정상', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: YbsColor.go300)),
                ),
              ),
              const Divider(height: 1, color: YbsColor.borderSoft),
              Padding(
                padding: const EdgeInsets.fromLTRB(YbsSpace.s4, YbsSpace.s3, YbsSpace.s4, 0),
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 20, color: YbsColor.textSub),
                    const SizedBox(width: YbsSpace.s3),
                    const Text('TTS 속도', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody)),
                    Expanded(
                      child: Slider(
                        value: _ttsRate,
                        activeColor: YbsColor.go500,
                        inactiveColor: YbsColor.ink600,
                        onChanged: (v) => setState(() => _ttsRate = v),
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                value: _autoTurn,
                onChanged: (v) => setState(() => _autoTurn = v),
                activeTrackColor: YbsColor.go600,
                secondary: const Icon(Icons.record_voice_over_outlined, size: 20, color: YbsColor.textSub),
                title: const Text('자동 턴 감지', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody)),
                subtitle: const Text('말이 끝나면 자동으로 전송 (준비 중)',
                    style: TextStyle(fontSize: YbsType.micro, color: YbsColor.textFaint)),
              ),
            ]),
            _section('데이터'),
            _card([
              const Padding(
                padding: EdgeInsets.all(YbsSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 20, color: YbsColor.textSub),
                    SizedBox(width: YbsSpace.s3),
                    Expanded(
                      child: Text(
                        '음성 원본은 저장하지 않아요. 대화는 텍스트로만 기록되고, 심판용 오디오는 처리 후 즉시 삭제돼요.',
                        style: TextStyle(fontSize: YbsType.sub, height: 1.5, color: YbsColor.textSub),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            _section('계정'),
            _card([
              _row(
                icon: Icons.logout,
                title: '로그아웃',
                onTap: _logout,
                trailing: const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ),
              const Divider(height: 1, color: YbsColor.borderSoft),
              _row(
                icon: Icons.person_remove_outlined,
                title: '회원 탈퇴',
                titleColor: YbsColor.live400,
                onTap: _deleteAccount,
                trailing: const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ),
            ]),
            _section('개발자'),
            _card([
              _row(
                icon: Icons.science_outlined,
                title: 'Day 1 스파이크',
                onTap: () => context.push('/spike'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ),
              const Divider(height: 1, color: YbsColor.borderSoft),
              _row(
                icon: Icons.replay,
                title: '온보딩 다시 보기',
                onTap: () => context.push('/onboarding'),
                trailing: const Icon(Icons.chevron_right, size: 18, color: YbsColor.textFaint),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(YbsSpace.s1, YbsSpace.s5, 0, YbsSpace.s2),
        child: Text(title,
            style: const TextStyle(fontSize: YbsType.micro, fontWeight: FontWeight.w700, color: YbsColor.textFaint)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: YbsColor.surfaceCard,
          border: Border.all(color: YbsColor.borderSoft),
          borderRadius: BorderRadius.circular(YbsRadius.md),
        ),
        // ListTile 잉크가 장식된 Container에 가려지는 문제 방지.
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: children),
        ),
      );

  Widget _row(
      {required IconData icon,
      required String title,
      Color? titleColor,
      Widget? trailing,
      VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: titleColor ?? YbsColor.textSub),
      title: Text(title,
          style: TextStyle(
              fontSize: YbsType.sub, color: titleColor ?? YbsColor.textBody)),
      trailing: trailing,
      dense: true,
    );
  }
}
