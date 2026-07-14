import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 치과 인트로 채팅(수민)에서 실제 기기 폭(328px, RenderFlex 오버플로
/// 로그의 BoxConstraints(w=328.0))에서 말풍선+시간 텍스트 합이 넘쳐
/// RenderFlex 오버플로가 나던 문제의 회귀 테스트. boss_intro_screen.dart의
/// `_friendRow` 구조를 그대로 재현한다(private 멤버라 직접 import 불가 —
/// onboarding_scroll_test.dart와 같은 방식).
///
/// 말풍선·시간 라벨은 고정 크기 SizedBox로 재현한다 — 실제 버그는 텍스트
/// 길이가 아니라 Column에 폭 제약이 없는 구조 자체의 결함이고, 테스트
/// 프레임워크의 대체 폰트는 실제 앱 폰트와 글자 폭이 달라 실제 문구로는
/// 신뢰성 있게 재현되지 않는다.
void main() {
  const bubbleWidth = 240.0; // ConstrainedBox(maxWidth: 240)이 실제로 다 찬 경우
  // 30(아바타)+8+240(말풍선)+6+48(시간) = 332 > 328(보고된 가용 폭) —
  // 실기기에서 시간 라벨 폭이 근사치(약 44px)보다 조금만 넓게 잡혀도
  // 마진 없이 바로 오버플로로 이어지는 실제 상황을 재현.
  const timeWidth = 48.0;

  Widget bubble() => const SizedBox(width: bubbleWidth, height: 40);
  Widget time() => const SizedBox(width: timeWidth, height: 14);

  // 수정 전 _friendRow 구조 — Column에 폭 제약이 없어 말풍선+시간 라벨
  // 합(30+8+240+6+44=328)이 남은 폭을 조금이라도 넘기면 오버플로.
  Widget oldFriendRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 30, height: 30),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('수민', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: bubbleWidth),
                  child: bubble(),
                ),
                const SizedBox(width: 6),
                time(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // 수정 후 _friendRow 구조 — Flexible로 감싸 남은 폭에 맞춰 줄어들게 함.
  Widget fixedFriendRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 30, height: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('수민', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: bubbleWidth),
                      child: bubble(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  time(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> pumpAtReportedWidth(WidgetTester tester, Widget row) async {
    // MediaQuery(data: ...)만 덮어씌우면 MediaQuery.of() 값만 바뀔 뿐
    // 실제 레이아웃 제약(RenderView 크기)은 안 바뀐다 — 반드시 테스트
    // 뷰 자체의 physicalSize를 설정해야 Row가 328px 제약을 실제로 받는다.
    tester.view.physicalSize = const Size(328, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: row)));
  }

  testWidgets('수정 전 구조는 보고된 폭에서 오버플로가 재현된다 (버그 확인용)',
      (tester) async {
    await pumpAtReportedWidth(tester, oldFriendRow());
    await tester.pump();
    expect(tester.takeException(), isNotNull,
        reason: '이 재현 시나리오 자체가 실패하면 아래 "고쳐짐" 테스트도 신뢰할 수 없음');
  });

  testWidgets('Flexible 적용 후에는 같은 폭에서 오버플로가 없다', (tester) async {
    await pumpAtReportedWidth(tester, fixedFriendRow());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
