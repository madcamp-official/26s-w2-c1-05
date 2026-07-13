import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 회원가입 화면에서 키보드가 올라올 때 "Bottom overflowed" 크래시가 나던 문제의
/// 회귀 테스트. 실제 [_loginPage]와 동일한 구조(Expanded 콘텐츠 + 고정 하단 풋터,
/// 이메일·비밀번호·비밀번호확인 3개 필드만큼의 콘텐츠 무게)를 재현해서, 키보드가
/// 뷰포트를 크게 잠식하는 극단적 상황에서도 오버플로 예외가 없는지 확인한다.
void main() {
  Widget scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }

  Widget signupFormLikeContent() {
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 110, height: 110), // hero circle
              const SizedBox(height: 24),
              const Text('계정으로 기록을 지켜요'),
              const SizedBox(height: 12),
              const Text('전적·도감·랭킹을 어느 기기에서든 이어가요.\n브라우저가 열리면 로그인해 주세요.'),
              const SizedBox(height: 24),
              Container(height: 52), // 이메일
              const SizedBox(height: 12),
              Container(height: 52), // 비밀번호
              const SizedBox(height: 12),
              Container(height: 52), // 비밀번호 확인 (회원가입 시에만 추가되는 필드)
              const SizedBox(height: 20),
              Container(height: 56), // 가입 버튼
              const SizedBox(height: 8),
              const Text('이미 계정이 있어요 — 로그인'),
            ],
          ),
        ),
        Container(height: 90), // _footer (dots + 캡션)
      ],
    );
  }

  Future<void> pumpWithKeyboard(WidgetTester tester, Widget body) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // 400x600 화면에서 키보드가 400px를 잡아먹는 상황 — 회원가입 시 실제
          // 보고된 재현 조건(좁은 화면 + 비밀번호 입력으로 키보드 표시)과 동일한 압박.
          data: const MediaQueryData(
            size: Size(400, 600),
            viewInsets: EdgeInsets.only(bottom: 400),
          ),
          child: Scaffold(body: SafeArea(child: body)),
        ),
      ),
    );
  }

  testWidgets('스크롤 래퍼 없이는 키보드 상황에서 오버플로가 재현된다 (버그 확인용)',
      (tester) async {
    await pumpWithKeyboard(tester, signupFormLikeContent());
    await tester.pump();
    expect(tester.takeException(), isNotNull,
        reason: '이 재현 시나리오 자체가 실패하면 아래 "고쳐짐" 테스트도 신뢰할 수 없음');
  });

  testWidgets('_scrollable 래퍼를 적용하면 같은 상황에서 오버플로 없이 렌더링된다',
      (tester) async {
    await pumpWithKeyboard(tester, scrollable(signupFormLikeContent()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
