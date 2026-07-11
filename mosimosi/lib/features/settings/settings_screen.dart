import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';

/// 6. 설정 — 닉네임/마이크 테스트/음성 설정/데이터 안내 (IA §3).
/// 값 저장은 미구현 — 화면 요소만. TTS 속도·턴 감지는 로컬 상태 데모.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _ttsRate = 0.5;
  bool _autoTurn = false;

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
                trailing: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('환불전사_수원', style: TextStyle(fontSize: YbsType.sub, color: YbsColor.textSub)),
                  SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 16, color: YbsColor.textFaint),
                ]),
              ),
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

  Widget _row({required IconData icon, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: YbsColor.textSub),
      title: Text(title, style: const TextStyle(fontSize: YbsType.sub, color: YbsColor.textBody)),
      trailing: trailing,
      dense: true,
    );
  }
}
