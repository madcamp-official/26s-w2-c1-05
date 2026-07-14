import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosimosi/features/history/session_detail_screen.dart';
import 'package:mosimosi/services/player_records.dart';

/// 전적 목록에서 어떤 판을 눌러도 항상 같은(82점 환불 상담원) 목업 화면만
/// 뜨던 버그의 회귀 테스트. [SessionDetailScreen]이 이제 sessionId로 실제
/// 조회한 [SessionDetail]을 렌더링하는지 — 그리고 judge가 없거나 트랜스크립트가
/// 비어 있는 판(중도 종료 등)에서도 크래시 없이 안전하게 표시되는지 확인한다.
void main() {
  SessionDetail chickenSession() => SessionDetail(
        id: 's1',
        mode: 'boss',
        bossId: 'chicken', // '환불'이 아닌 다른 보스로 — 항상 환불이 뜨던 버그와 구분
        startedAt: DateTime(2026, 7, 14, 21, 4),
        endedAt: DateTime(2026, 7, 14, 21, 6),
        result: 'win',
        score: 91,
        judge: const {
          'cleared': true,
          'score': 91,
          'verdictLine': '메뉴·주소를 정확히 전달함',
          'conditions': [],
          'improvements': [],
          'deliveryNote': '',
          'oneLiner': '깔끔한 주문이었어요',
          'fillerCount': 0,
          'silenceCount': 0,
          'highlightQuote': '',
          'highlightContext': '',
        },
        transcript: [
          TranscriptLine(speaker: 'boss', text: '네 사장님입니다', tStartMs: 0),
          TranscriptLine(speaker: 'user', text: '후라이드 한 마리요', tStartMs: 2000),
        ],
      );

  testWidgets('클릭한 세션의 실제 보스 이름·점수가 표시된다 (버그 확인용 — 항상 환불이 뜨면 안 됨)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SessionDetailScreen(
        sessionId: 's1',
        fetcher: (_) async => chickenSession(),
      ),
    ));
    await tester.pumpAndSettle();

    // 헤더 제목 + 트랜스크립트의 보스 발화자 이름 둘 다에 나타나는 게 정상.
    expect(find.text('무던한 치킨집 사장님'), findsWidgets);
    expect(find.text('91점'), findsOneWidget);
    expect(find.textContaining('환불'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('judge가 null이어도(중도 종료 판) 크래시 없이 안내 문구를 보여준다', (tester) async {
    final noJudge = SessionDetail(
      id: 's2',
      mode: 'boss',
      bossId: 'dental',
      startedAt: DateTime(2026, 7, 14, 12, 0),
      endedAt: DateTime(2026, 7, 14, 12, 1),
      result: null,
      score: null,
      judge: null,
      transcript: const [],
    );
    await tester.pumpWidget(MaterialApp(
      home: SessionDetailScreen(
        sessionId: 's2',
        fetcher: (_) async => noJudge,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('저장된 대화 기록이 없어요'), findsOneWidget);
    expect(find.textContaining('판정 리포트가 저장되지 않았어요'), findsOneWidget);
    expect(find.text('진행중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('조회 실패 시 에러 문구와 재시도 버튼을 보여준다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SessionDetailScreen(
        sessionId: 's3',
        fetcher: (_) async => throw Exception('network'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('전적을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
