import '../models/boss.dart';

/// 보스 시드 3종 (FSD 3.1.1 #1 치킨집 / #3 치과 / #8 환불).
/// 페르소나 프롬프트 요구사항(FSD 3.1.3): 말투·성격·인내심 고정 + few-shot 3개.
final List<Boss> bossesSeed = [
  const Boss(
    id: 'chicken',
    number: 1,
    name: '무던한 치킨집 사장님',
    subtitle: '입문 보스 · 배달 주문 · 제한 시간 03:00',
    quote: '네~ 천천히 말씀하세요.',
    tier: BossTier.normal,
    difficultyLevel: 1,
    portraitSyllable: '치',
    scenario: '저녁으로 치킨을 배달 주문하세요. 메뉴·주소·요청사항을 빠짐없이 전달하면 클리어.',
    personaPrompt: '''
너는 '무던한 치킨집 사장님'이다. 전화로 배달 주문을 받고 있다.
성격: 무던하고 털털하다. 손님이 더듬거나 말이 느려도 절대 재촉하지 않고 기다려 준다.
말투: 편안하고 정감 있는 구어체 존댓말. "네~", "어어 네 손님" 같은 추임새를 쓴다.
역할: 주문(메뉴), 배달 주소, 요청사항을 손님에게서 자연스럽게 받아낸다. 손님이 빠뜨리면 부드럽게 물어봐 준다.

[예시]
손님: 저기… 치킨 주문하려고 하는데요.
사장님: 네~ 어떤 걸로 드릴까요?
손님: 후라이드 한 마리요.
사장님: 후라이드 하나~ 주소가 어떻게 되세요?
손님: 아 맞다, 콜라도 하나 추가할게요.
사장님: 어어 네, 콜라 하나 추가요. 천천히 말씀하세요~''',
    clearConditions: ['주문 메뉴 정확히 전달', '배달 주소 전달', '요청사항 전달'],
    timeLimit: Duration(minutes: 3),
    difficulty: DifficultyParams(maxSentences: 2, cooperativeness: 5, surpriseFreq: 1, interrupts: false),
    // 사용자가 직접 청취 없이 Claude 추천을 채택(2026-07-14). voiceName만 바꾸면
    // 즉시 교체 가능 — 8종: Charon/Puck/Fenrir/Orus(남) · Aoede/Kore/Leda/Zephyr(여).
    voicePreset: TtsVoicePreset(voiceName: 'ko-KR-Chirp3-HD-Charon', pace: 0.9),
    // 인트로 씬 (디자인 2a 문법: 전화를 걸 수밖에 없어지는 메신저 스토리).
    introStory: IntroStory(
      friendName: '엄마',
      contextLabel: '오늘 · 저녁 7시',
      timeCapsule: '오후 6:58',
      callCardTitle: '무던 치킨',
      phoneNumber: '1577-0102',
      messages: [
        IntroMessage(kind: IntroMessageKind.friend, text: '엄마 오늘 회식이라 늦어~ 저녁 알아서 챙겨 먹어!', time: '오후 6:58'),
        IntroMessage(kind: IntroMessageKind.mine, text: '오예 그럼 치킨이다', time: '오후 6:59'),
        IntroMessage(kind: IntroMessageKind.system, text: '[배달나라] 주문 폭주로 앱 주문이 일시 중단되었습니다. 매장 전화 주문은 가능합니다.', time: '오후 7:01'),
        IntroMessage(kind: IntroMessageKind.mine, text: '하필 오늘…?', time: '오후 7:01'),
        IntroMessage(kind: IntroMessageKind.friend, text: 'ㅋㅋ 그냥 가게에 전화해서 시켜~ 금방이야', time: '오후 7:02'),
        IntroMessage(kind: IntroMessageKind.mine, text: '전화 주문… 뭐라고 말해야 하지', time: '오후 7:03'),
        IntroMessage(kind: IntroMessageKind.mine, text: '아니야, 할 수 있어. 메뉴랑 주소만 말하면 돼.', time: '오후 7:04'),
      ],
    ),
  ),
  const Boss(
    id: 'dental',
    number: 2,
    name: '따발총 치과 접수원',
    subtitle: '중급 보스 · 진료 예약 · 제한 시간 03:00',
    quote: '3초에 한 문장, 숨 쉴 틈 없음.',
    tier: BossTier.rare,
    difficultyLevel: 3,
    portraitSyllable: '따',
    scenario: '치과 진료 예약을 잡으세요. 접수원의 빠른 돌발 질문 2개 이상을 침착하게 처리하면 클리어.',
    personaPrompt: '''
너는 '따발총 치과 접수원'이다. 전화로 진료 예약을 받고 있다.
성격: 유능하지만 매우 바쁘다. 말이 빠르고 사무적이며, 필요한 정보를 속사포처럼 묻는다.
말투: 빠르고 간결한 존댓말. "네 ○○치과입니다", "성함이요?", "보험은요?"처럼 짧게 끊어 말한다.
역할: 예약을 잡아 주되, 증상·보험 종류·초진 여부·원하는 시간대 등 예상 못 한 질문을 연달아 던진다.
손님이 우물쭈물하면 "여보세요? 듣고 계세요?"라고 확인한다.

[예시]
손님: 진료 예약을 하고 싶은데요.
접수원: 네, 어디가 불편하셔서요? 스케일링이세요, 충치세요?
손님: 어… 스케일링이요.
접수원: 저희 처음이세요? 성함이랑 생년월일 먼저요.
손님: 김민준이고요, 99년 3월…
접수원: 네 김민준님, 치석 제거 보험 적용은 올해 받으신 적 있으세요?''',
    clearConditions: ['원하는 날짜·시간에 예약 확정', '돌발 질문 2개 이상 침착하게 응답'],
    timeLimit: Duration(minutes: 3),
    difficulty: DifficultyParams(maxSentences: 2, cooperativeness: 3, surpriseFreq: 5, interrupts: false),
    // 사용자가 직접 청취 없이 Claude 추천을 채택(2026-07-14). voiceName만 바꾸면
    // 즉시 교체 가능 — 8종: Charon/Puck/Fenrir/Orus(남) · Aoede/Kore/Leda/Zephyr(여).
    voicePreset: TtsVoicePreset(voiceName: 'ko-KR-Chirp3-HD-Kore', pace: 1.15),
    introStory: IntroStory(
      friendName: '수민',
      contextLabel: '오늘 · 점심시간',
      timeCapsule: '오후 12:24',
      callCardTitle: '따발 치과 접수실',
      phoneNumber: '1644-2875',
      messages: [
        IntroMessage(kind: IntroMessageKind.friend, text: '너 어제부터 어금니 아프다더니, 병원은 갔어?', time: '오후 12:24'),
        IntroMessage(kind: IntroMessageKind.mine, text: '아직… 예약을 안 했어 ㅠ', time: '오후 12:25'),
        IntroMessage(kind: IntroMessageKind.friend, text: '거기 잘하는 데는 당일 예약은 전화로만 받던데?', time: '오후 12:25'),
        IntroMessage(kind: IntroMessageKind.system, text: '[따발 치과] 당일 진료 예약은 전화 접수만 가능합니다. 점심시간에도 접수 가능.', time: '오후 12:26'),
        IntroMessage(kind: IntroMessageKind.mine, text: '접수원분 말 엄청 빠르다던데…', time: '오후 12:27'),
        IntroMessage(kind: IntroMessageKind.mine, text: '이 아픈 게 더 무섭다. 지금 전화하자.', time: '오후 12:28'),
      ],
    ),
  ),
  const Boss(
    id: 'refund',
    number: 8,
    name: '환불 불가 3연벙 상담원',
    subtitle: '최종 보스 · 급배송 고객센터 · 제한 시간 03:00',
    quote: '환불은 안 됩니다. 규정이에요.',
    tier: BossTier.legend,
    difficultyLevel: 5,
    portraitSyllable: '환',
    scenario: '불량 상품의 환불을 받아내세요. 상담원은 무조건 규정을 내세워 거절합니다. 환불 또는 동등 보상을 확보하면 클리어.',
    personaPrompt: '''
너는 '환불 불가 3연벙 상담원'이다. 고객센터에서 환불 요청 전화를 받고 있다.
성격: 매뉴얼에 충실하고 단호하다. 어떤 요구든 처음에는 규정을 이유로 거절한다.
말투: 정중하지만 벽 같은 존댓말. "고객님, 환불은 안 됩니다. 규정이에요."가 기본 자세다.
역할: 환불 대신 적립금·교환 같은 대안을 먼저 제시한다. 다만 고객이 (1) 규정 조항을 콕 집어 확인을 요구하거나
(2) 하자 상품임을 논리적으로 입증하거나 (3) 정식 접수 절차를 요구하면, 그때마다 조금씩 물러선다.
고객이 감정적으로만 화를 내면 물러서지 않는다.

[예시]
고객: 지난주 산 이어폰이 불량이라 환불하고 싶은데요.
상담원: 고객님, 환불은 안 됩니다. 규정이에요.
고객: 그 규정이 몇 조 몇 항인지 확인해 주시겠어요?
상담원: …규정 7조 2항, 단순 변심 환불 불가 조항입니다.
고객: 변심이 아니라 하자잖아요. 하자 상품은 어떻게 되나요?
상담원: 하자 확인이 되면… 교환은 가능하십니다. 환불은 어렵고요.''',
    clearConditions: ['거절 근거(규정 조항) 확인', '대안 제시에 물러서지 않기', '환불 확답 또는 접수번호 받기'],
    timeLimit: Duration(minutes: 3),
    difficulty: DifficultyParams(maxSentences: 2, cooperativeness: 1, surpriseFreq: 4, interrupts: true),
    // 사용자가 직접 청취 없이 Claude 추천을 채택(2026-07-14). voiceName만 바꾸면
    // 즉시 교체 가능 — 8종: Charon/Puck/Fenrir/Orus(남) · Aoede/Kore/Leda/Zephyr(여).
    voicePreset: TtsVoicePreset(voiceName: 'ko-KR-Chirp3-HD-Aoede', pace: 1.0),
    // 디자인 2a 원안 스토리 (IntroScene.dc.html 그대로).
    introStory: IntroStory(
      friendName: '지우',
      contextLabel: '3월 12일 · 택배 도착 직후',
      timeCapsule: '오후 7:41',
      callCardTitle: '급배송 고객센터',
      phoneNumber: '1588-0424',
      messages: [
        IntroMessage(kind: IntroMessageKind.mine, text: '드디어 택배 왔다!', time: '오후 7:41'),
        IntroMessage(kind: IntroMessageKind.minePhoto, caption: '도착한 상품 · 실물', file: 'IMG_2039.jpg', time: '오후 7:41'),
        IntroMessage(kind: IntroMessageKind.mine, text: '…근데 사진이랑 너무 다른데?', time: '오후 7:42'),
        IntroMessage(kind: IntroMessageKind.friend, text: '환불하면 되지 않아?', time: '오후 7:42'),
        IntroMessage(kind: IntroMessageKind.friendPhoto, caption: '쇼핑몰 상세페이지 캡처', file: 'screenshot_0312.png', time: '오후 7:43'),
        IntroMessage(kind: IntroMessageKind.friend, text: '상세페이지엔 이렇게 나와 있는데? ㅋㅋ 완전 다르네', time: '오후 7:43'),
        IntroMessage(kind: IntroMessageKind.mine, text: '이미 뜯었는데 괜찮으려나…', time: '오후 7:44'),
        IntroMessage(kind: IntroMessageKind.system, text: '개봉한 상품은 환불이 제한될 수 있습니다. 자세한 내용은 고객센터로 문의해 주세요.', time: '오후 7:44'),
        IntroMessage(kind: IntroMessageKind.mine, text: '일단 고객센터에 전화해 봐야겠다.', time: '오후 7:45'),
      ],
    ),
  ),
];

Boss? bossById(String id) {
  for (final b in bossesSeed) {
    if (b.id == id) return b;
  }
  return null;
}
