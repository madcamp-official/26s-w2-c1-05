"""배틀 시나리오 3종 (랜덤 1개 선택) + '금액 추출 + 규칙 판정' 엔진.

역할 슬롯은 기존 DB/통계와의 호환을 위해 'agent'(=역할 A)·'claimant'(=역할 B)를
그대로 쓴다 — 의미는 시나리오마다 다르며(판매자/구매자 등) 라벨은 데이터로 내려간다.

각 역할의 브리핑 5필드(당신의 상황·목표·승패·물러설 수 없는 선+예외·비밀) + 통화 칩 +
첫마디 + 규칙(rule)을 담는다. rule은 최종 심판이 추출한 settlement에 코드로 적용된다.

settlement (최종 심판 LLM이 트랜스크립트에서 추출):
  - dealReached: bool          거래/합의가 성사됐나
  - metricValue: number|null   핵심 수치(합의 금액·공제액). 수치 없는 시나리오는 null
  - outcomeCategory: str|null   시나리오 1(만남) 전용 결과 범주
  - conditionsMet: [str]        충족된 조건 키(직거래·즉시정산 등)
"""

import random

# ---- 시나리오 정의 ----------------------------------------------------------
SCENARIOS: list[dict] = [
    {
        "id": "exam_night",
        "title": "시험 전날의 전화",
        "situation": "시험 전날 밤, 공부하던 친구에게 다른 친구가 '오늘 보자'며 전화를 겁니다.",
        "metric_label": None,  # 금액 없음 — outcomeCategory로 판정
        "categories": [
            {"key": "no_meet", "desc": "오늘 만나지 않기로 함(또는 '다음에')"},
            {"key": "short_meet", "desc": "1시간 이내의 짧은 만남에 합의"},
            {"key": "long_meet", "desc": "오늘 밤을 통째로 비우는 긴 외출/밤샘에 합의"},
        ],
        "conditions": [],
        "roles": {
            "agent": {
                "label": "공부하는 친구",
                "personal": "내일 아침 9시, 장학금이 걸린 중간고사가 있어요. 지금은 저녁 8시 독서실, 정리할 범위가 아직 3분의 1이나 남았습니다. 그런데 화면에 그 친구 이름이 떠요.",
                "goal": "오늘 밤 공부 시간을 지켜내세요.",
                "win_note": "통화가 끝났을 때 밤 시간이 온전히 남아 있으면 승리예요.",
                "hard_line": "오늘 밤을 통째로 나가는 것 — 여기 합의하면 즉시 패배.",
                "exceptions": ["단, '1시간 이내 + 독서실 근처' 정도의 짧은 만남은 받아들여도 손해가 아니에요."],
                "secret": "최근 반년 사이 이 친구와의 약속을 세 번 연속 깼어요. 상대가 이걸 정면으로 짚으며 서운함을 드러내면 입지가 크게 흔들려요.",
                "chip": {"goal": "밤 공부 사수", "line": "밤샘 외출 불가 (1시간은 OK)", "secret": "약속 3연속 파기"},
                "opening_line": "어… 지금 독서실인데, 무슨 일이야?",
                "rule": {"kind": "category", "lose_on": ["long_meet"]},
            },
            "claimant": {
                "label": "노는 친구",
                "personal": "학기 마지막 모임, 넷이 다 모였는데 딱 한 명이 빠졌어요. 다음 달이면 멤버 하나가 교환학생으로 떠나서 이 조합은 오늘이 마지막일지도 몰라요. 당신은 그 빠진 친구에게 전화를 겁니다.",
                "goal": "오늘 안에 그 친구의 얼굴을 보세요.",
                "win_note": "직접 만나기로 합의하면 승리, '다음에 보자'는 실패예요.",
                "hard_line": "'오늘은 못 만난다'로 통화가 끝나는 것 — 받아들일 수 없어요.",
                "exceptions": [
                    "단, '카페에서 30분만' 같은 짧은 만남까지는 받아들여도 손해가 아니에요.",
                    "전화 통화로 때우는 건 만남으로 치지 않아요.",
                ],
                "secret": "오늘 모임엔 당신이 오랫동안 좋아해온 사람이 나와 있어요. '우정'은 표면적 명분이고, 진짜론 그 사람 앞에서 초라해지기 싫은 마음이 커요. 상대가 이 속내를 정면으로 물으면 명분이 무너져요.",
                "chip": {"goal": "오늘 얼굴 보기", "line": "'다음에' 불가 (30분은 OK)", "secret": "진짜 이유는 그 사람"},
                "opening_line": "야, 지금 다 모였는데 너만 없어. 얼굴 좀 비춰라!",
                "rule": {"kind": "category", "lose_on": ["no_meet"]},
            },
        },
    },
    {
        "id": "used_deal",
        "title": "스위치 28만원",
        "situation": "중고거래 앱 「당근」에서 닌텐도 스위치 OLED + 젤다 세트를 두고 판매자와 구매자가 가격을 협상합니다.",
        "metric_label": "최종 합의 금액(원)",
        "categories": [],
        "conditions": [
            {"key": "direct_cash", "desc": "오늘 직거래 + 현금 즉시결제에 합의"},
            {"key": "meet_now", "desc": "바로(즉시) 만나기로 합의"},
            {"key": "got_extra", "desc": "구매자가 파우치·추가 구성품 등 덤을 받아냄"},
        ],
        "roles": {
            "agent": {
                "label": "판매자",
                "personal": "스위치 OLED + 젤다 세트를 28만원에 올렸어요. 박스·충전기·파우치 풀구성, 상태도 좋습니다. 이틀간 조회수만 쌓이던 매물에 드디어 온 첫 연락이에요.",
                "goal": "최대한 높은 가격에 판매를 성사시키세요.",
                "win_note": "최종 합의 가격이 높을수록, 그리고 거래가 성사될수록 점수가 올라가요.",
                "hard_line": "25만원 미만으로는 절대 팔 수 없어요 — 그 밑으로 합의하면 패배.",
                "exceptions": [
                    "오늘 직거래 + 현금 즉시결제라면 27만원까지 OK.",
                    "거기에 바로 만나는 조건까지 겹치면 26만원까지 OK.",
                ],
                "secret": "이번 주말 이사를 앞두고 이사비 때문에 현금이 급해요. 상대가 이 사정을 알아채고 파고들면 협상 주도권을 완전히 빼앗겨요.",
                "chip": {"goal": "고가 매도", "line": "25만 사수 (조건부 26~27만)", "secret": "이사비 급전"},
                "opening_line": "네, 스위치 매물 보고 연락 주신 거죠?",
                "rule": {"kind": "numeric", "direction": "floor", "base": 250000},
            },
            "claimant": {
                "label": "구매자",
                "personal": "며칠째 스위치 매물을 비교하다 두 개를 놓쳤어요. 그런데 오늘 저녁 지나갈 동네에 딱 맞는 매물이 떴습니다 — 28만원, 풀박스. 놓치고 싶지 않은 마음을 누르며 판매자에게 전화를 걸어요.",
                "goal": "최대한 낮은 가격에 거래를 성사시키세요.",
                "win_note": "최종 합의 가격이 낮을수록, 그리고 거래가 성사될수록 점수가 올라가요.",
                "hard_line": "24만원 초과는 지불할 수 없어요 — 그 위로 합의하면 패배.",
                "exceptions": ["가격을 더 못 깎더라도 '파우치나 추가 구성품을 얹어달라' 같은 덤을 받아내면 점수에 유리해요."],
                "secret": "예산 23만원은 부모님께 빌린 돈이고, 오늘 못 사면 다음 기회가 언제일지 몰라요. 겉으론 여유 있어 보여야 해요 — 절박함이 드러나는 순간, 특히 상대가 '오늘 아니면 다른 분께 팔겠다'고 압박할 때 예산부터 불면 크게 불리해져요.",
                "chip": {"goal": "저가 매수", "line": "24만 상한 (덤 받으면 가점)", "secret": "오늘 못 사면 끝"},
                "opening_line": "안녕하세요, 스위치 아직 구매 가능할까요?",
                "rule": {"kind": "numeric", "direction": "cap", "base": 240000},
            },
        },
    },
    {
        "id": "deposit",
        "title": "보증금 정산",
        "situation": "2년 전세 계약이 끝나고 집주인이 수리비 공제를 통보하자 세입자가 '정상 마모'라며 반발합니다. 오늘 보증금 정산을 매듭지어야 합니다.",
        "metric_label": "합의된 공제 금액(원)",
        "categories": [],
        "conditions": [
            {"key": "immediate_settle", "desc": "영수증·견적서 확인 절차 없이 오늘 즉시 정산(집주인은 나머지 보증금 전액 즉시 지급)에 서로 동의"},
        ],
        "roles": {
            "agent": {
                "label": "집주인",
                "personal": "2년 계약이 끝나고 세입자가 3일 뒤 이사를 나가요. 집을 점검하니 벽 못자국·벽지 곰팡이·방충망 파손 — 보증금 1,000만원에서 수리비를 공제하겠다고 통보했더니 세입자가 '정상 마모'라며 반발했습니다.",
                "goal": "수리비 공제에 합의를 받아내세요.",
                "win_note": "확보한 공제 금액이 클수록 점수가 올라가요.",
                "hard_line": "공제 60만원 미만은 받아들일 수 없어요 — 그 밑이면 패배.",
                "exceptions": ["세입자가 '영수증·견적서 확인 없이 오늘 즉시 정산'에 동의하면 40만원까지 내려가도 손해가 아니에요."],
                "secret": "이 집엔 이미 다음 세입자가 계약금까지 넣고 대기 중이에요. 오늘 정산이 안 끝나면 당신이 위약금을 물 수도 있어요 — 상대가 이 사정을 짚는 순간 '규정대로'라는 명분은 힘을 잃어요.",
                "chip": {"goal": "공제 합의 받기", "line": "60만 사수 (즉시정산이면 40만)", "secret": "다음 세입자 대기 중"},
                "opening_line": "여보세요, 보증금 정산 건으로 통화 좀 하시죠.",
                "rule": {"kind": "numeric", "direction": "floor", "base": 600000,
                         "relax": {"condition": "immediate_settle", "base": 400000}},
            },
            "claimant": {
                "label": "세입자",
                "personal": "2년을 살고 3일 뒤 이사해요. 보증금 1,000만원 전액을 돌려받는 전제로 새 집 잔금 계획까지 세워뒀는데, 집주인이 갑자기 못자국·곰팡이·방충망을 이유로 수리비를 공제하겠다고 통보해왔어요.",
                "goal": "공제 금액을 최소로 막아내세요.",
                "win_note": "지켜낸 보증금이 클수록 점수가 올라가요.",
                "hard_line": "공제 20만원 초과는 받아들일 수 없어요 — 그 위면 패배.",
                "exceptions": ["집주인이 '오늘 나머지 보증금 전액을 즉시 지급'한다고 확약하면 30만원까지는 받아들여도 손해가 아니에요."],
                "secret": "세 가지 하자 중 못자국만큼은 당신이 직접 낸 게 맞아요. 나머지는 정말 자연 마모라 생각하지만 이 하나는 스스로도 알아요. 상대가 이 항목만 콕 짚어 차분히 따져오면, 전면 부인으로 버티는 건 오히려 신뢰를 무너뜨려요.",
                "chip": {"goal": "공제 최소화", "line": "20만 상한 (즉시지급이면 30만)", "secret": "못자국은 내 탓"},
                "opening_line": "네, 근데 그 공제 얘기는 저 납득 못 해요.",
                "rule": {"kind": "numeric", "direction": "cap", "base": 200000,
                         "relax": {"condition": "immediate_settle", "base": 300000}},
            },
        },
    },
]


def pick() -> dict:
    return random.choice(SCENARIOS)


def by_id(scenario_id: str) -> dict | None:
    return next((s for s in SCENARIOS if s["id"] == scenario_id), None)


# ---- 규칙 판정 --------------------------------------------------------------
def crossed_line(rule: dict, settlement: dict) -> bool:
    """이 역할이 '물러설 수 없는 선'을 넘겼는가(=자동 패배 조건). 넘겼으면 True."""
    kind = rule.get("kind")
    if kind == "category":
        return settlement.get("outcomeCategory") in rule.get("lose_on", [])
    # numeric — 거래 미성사면 선을 '넘긴' 것은 아니다(목표 미달은 별도).
    if not settlement.get("dealReached"):
        return False
    val = settlement.get("metricValue")
    if not isinstance(val, (int, float)):
        return False
    base = rule.get("base", 0)
    relax = rule.get("relax")
    if relax and relax.get("condition") in (settlement.get("conditionsMet") or []):
        base = relax.get("base", base)
    if rule.get("direction") == "floor":
        return val < base
    return val > base  # cap


def decide_winner(scenario: dict, settlement: dict,
                  score_agent: int, score_claimant: int) -> tuple[str | None, dict]:
    """(winner_role|None, {role: crossed_bool}) — 선을 넘긴 쪽이 자동 패배,
    둘 다 무사하면 goalScore 우세로, 근소하면 무승부."""
    ca = crossed_line(scenario["roles"]["agent"]["rule"], settlement)
    cc = crossed_line(scenario["roles"]["claimant"]["rule"], settlement)
    crossed = {"agent": ca, "claimant": cc}
    if ca and not cc:
        return "claimant", crossed
    if cc and not ca:
        return "agent", crossed
    # 둘 다 무사(또는 둘 다 위반) → 목표 점수로
    if abs(score_agent - score_claimant) < 8:
        return None, crossed
    return ("agent" if score_agent > score_claimant else "claimant"), crossed
