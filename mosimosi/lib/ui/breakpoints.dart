import 'package:flutter/widgets.dart';

/// 반응형 폼팩터 분기. 두 폼팩터는 동등한 게임 클라이언트 — 레이아웃 차이일 뿐.
enum FormFactor { mobile, desktop }

class Breakpoints {
  Breakpoints._();

  /// 이 폭 이상이면 데스크톱(와이드) 레이아웃.
  static const double desktop = 840;
}

FormFactor formFactorOf(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= Breakpoints.desktop
      ? FormFactor.desktop
      : FormFactor.mobile;
}

bool isDesktop(BuildContext context) =>
    formFactorOf(context) == FormFactor.desktop;
