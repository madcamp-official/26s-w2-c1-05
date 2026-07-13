import 'package:flutter/material.dart';

/// 여보세요 디자인 토큰 — claude.ai/design 프로토타입에서 추출.
/// Dark-first 게임 UI. 화면 위젯은 색상을 하드코딩하지 말고 여기를 참조한다.
///
/// 폰트: Black Han Sans(디스플레이) / Pretendard(본문) / IBM Plex Mono(숫자).
/// assets/fonts/에 번들, pubspec에 등록됨 (모두 SIL OFL).

/// 색상 팔레트 (tokens/colors.css).
class YbsColor {
  YbsColor._();

  // ---- ink: 야간 네이비-블랙 ----
  static const ink950 = Color(0xFF060810);
  static const ink900 = Color(0xFF0B0E16);
  static const ink850 = Color(0xFF101522);
  static const ink800 = Color(0xFF161C2A);
  static const ink700 = Color(0xFF1A2130);
  static const ink600 = Color(0xFF242E42);
  static const ink500 = Color(0xFF364258);
  static const ink400 = Color(0xFF55627A);
  static const ink300 = Color(0xFF8391A8);
  static const ink200 = Color(0xFFB3BECF);
  static const ink100 = Color(0xFFE2E8F2);
  static const white = Color(0xFFF7FAFF);

  // ---- signals ----
  static const go600 = Color(0xFF17B84E);
  static const go500 = Color(0xFF2CE06B); // 통화 수락 그린 = 행동/용기/승리
  static const go400 = Color(0xFF5CF08F);
  static const go300 = Color(0xFF8DF7B2);

  static const live600 = Color(0xFFD92B3C);
  static const live500 = Color(0xFFFF4655); // 끊기/녹음 레드 = 긴장/보스/ON AIR
  static const live400 = Color(0xFFFF7581);

  static const gold500 = Color(0xFFE8A912);
  static const gold400 = Color(0xFFFFC531);
  static const gold300 = Color(0xFFFFDD7A);

  static const amber400 = Color(0xFFFFB020);
  static const sky400 = Color(0xFF5BC8FF);

  // ---- glows (base @ alpha) ----
  static Color get goGlow => go500.withValues(alpha: 0.35);
  static Color get liveGlow => live500.withValues(alpha: 0.40);
  static Color get goldGlow => gold400.withValues(alpha: 0.35);

  // ---- semantic: 게임 레지스터 (기본 — 홈/도감/결과 등) ----
  static const bgApp = ink950;
  static const bgRaised = ink900;
  static const surfaceCard = ink850;
  static const surfaceCardHover = ink700;
  static const surfaceInset = Color(0xFF0A0D14);
  static const borderSoft = Color(0xFF232C3E);
  static const borderStrong = Color(0xFF364258);

  // ---- 라이브 레지스터 (data-mode="incall" — 통화 화면 전용) ----
  static const bgIncall = Color(0xFF0A0509);
  static const surfaceIncall = Color(0xFF170D12);
  static const borderIncall = Color(0xFF3A1B22);

  // ---- text ----
  static const textHero = white;
  static const textBody = ink100;
  static const textSub = ink300;
  static const textFaint = ink400;
  static const textOnGo = Color(0xFF04170B);
  static const textOnGold = Color(0xFF241A02);
  static const textOnLive = Color(0xFFFFF4F5);
}

/// 타이포 (tokens/typography.css). 크기는 논리 px.
class YbsType {
  YbsType._();

  static const display = 'BlackHanSans'; // 미번들 → 폴백
  static const body = 'Pretendard';
  static const numeric = 'IBMPlexMono';

  static const poster = 44.0;
  static const displaySize = 34.0;
  static const title = 24.0;
  static const timer = 40.0;
  static const captionLive = 21.0; // 통화 자막 — 이보다 작게 금지
  static const bodyLg = 18.0;
  static const bodyMd = 16.0;
  static const sub = 14.0;
  static const micro = 12.0;

  static const leadingTight = 1.15;
  static const leadingSnug = 1.3;
  static const leadingBody = 1.55;

  /// 대문자 라틴 마이크로 라벨용 letter-spacing (CSS 0.08em → size 비례).
  static double labelTracking(double size) => size * 0.08;
}

/// 간격 (tokens/spacing.css). 4 기반.
class YbsSpace {
  YbsSpace._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0; // 화면 패딩(모바일)
  static const s6 = 24.0;
  static const s8 = 32.0; // 화면 패딩(데스크톱)
  static const s10 = 40.0;
  static const s14 = 56.0;

  static const hitMin = 44.0; // 최소 히트 타깃
  static const hitCall = 72.0; // 수락/거절 원
}

/// 라운드 (tokens/spacing.css).
class YbsRadius {
  YbsRadius._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0; // 버튼
  static const lg = 20.0; // 카드
  static const xl = 28.0;
  static const full = 999.0;
}

/// 레이아웃/반응형 (tokens/layout.css).
class YbsLayout {
  YbsLayout._();
  static const bpMedium = 720.0;
  static const bpExpanded = 1200.0; // 데스크톱 폰-스테이지 시작점

  // in-call 데스크톱 스테이지
  static const stagePhoneW = 390.0; // 중앙 폰 목업 고정폭
  static const stagePhoneRadius = 40.0; // 목업 베젤
  static const stageHudW = 320.0; // 좌우 HUD 패널 폭
  static const stageGap = 24.0;
  static const stageTopH = 88.0; // 상단 모멘텀 게이지 스트립
  static const screenPadDesktop = 32.0;
}

/// 그림자/글로우 (tokens/effects.css). Flutter는 inset 미지원 → drop만 근사.
class YbsShadow {
  YbsShadow._();
  static const card = [
    BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const pop = [
    BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 18)),
  ];
}

/// 전역 테마 — dark-first. 통화 배경을 스캐폴드 기본으로.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: YbsColor.bgApp,
  fontFamily: YbsType.body,
  colorScheme: const ColorScheme.dark(
    primary: YbsColor.go500,
    secondary: YbsColor.gold400,
    error: YbsColor.live500,
    surface: YbsColor.surfaceCard,
  ),
);
