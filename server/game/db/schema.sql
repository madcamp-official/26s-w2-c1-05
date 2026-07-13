-- 여보세요 DB 스키마 (PostgreSQL 15+)
-- 원칙: 보스 정의는 코드 시드(진실의 원천), DB는 진행·기록만.
--       음성 원본 컬럼 없음(규칙 #5). 채점 시간축은 t_start_ms(규칙 #3).

-- 1. 유저 — 소셜/일반 로그인 계정 (provider+provider_id가 식별자, auth.py)
CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider      text NOT NULL,               -- 'google' | 'kakao' | 'local'(이메일 가입)
  provider_id   text NOT NULL,               -- 프로바이더 계정 고유 ID (local은 이메일 소문자)
  email         text,                        -- 프로바이더 제공 (카카오 미동의 시 null)
  password_hash text,                        -- bcrypt — local 계정만 사용
  nickname      text UNIQUE,                 -- null = 온보딩(닉네임 설정) 미완
  elo           int  NOT NULL DEFAULT 1500,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz,
  UNIQUE (provider, provider_id)
);

-- 2. 도감 진행 (잠금/해금/격파 + 최고 기록)
CREATE TABLE IF NOT EXISTS boss_progress (
  user_id     uuid NOT NULL REFERENCES users(id),
  boss_id     text NOT NULL,                -- 'chicken' | 'dental' | 'refund' ...
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  cleared_at  timestamptz,                  -- null = 미격파
  best_score  int,
  attempts    int NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, boss_id)
);

-- 3. 배틀 방 (상태머신: waiting→matched→briefing→in_call→judging→done|aborted)
CREATE TABLE IF NOT EXISTS battle_rooms (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  state          text NOT NULL DEFAULT 'matched',
  scenario       jsonb NOT NULL,            -- 공통 상황만 (비밀은 battle_players에)
  time_limit_s   int  NOT NULL DEFAULT 300,
  started_at     timestamptz,               -- in_call 진입 = 통화 시작(0ms 기준점)
  ended_at       timestamptz,
  winner_user_id uuid REFERENCES users(id),
  final_momentum int,                       -- 0~100 (승자 관점)
  verdict        jsonb,                     -- 최종 심판 공통 판정(루브릭·근거 인용)
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- 4. 배틀 참가자 — ★비밀 정보 행 단위 격리 (규칙 #2)
CREATE TABLE IF NOT EXISTS battle_players (
  room_id       uuid NOT NULL REFERENCES battle_rooms(id),
  user_id       uuid NOT NULL REFERENCES users(id),
  role          text NOT NULL,              -- 'claimant' | 'agent'
  form_factor   text NOT NULL,              -- 'android' | 'windows'
  secret_goal   text NOT NULL,
  rule_card     text,                       -- 상담원 전용
  goal_achieved boolean,
  ready_at      timestamptz,
  elo_delta     int,
  PRIMARY KEY (room_id, user_id)
);

-- 5. 판(세션) — 싱글·배틀 공용. 배틀은 방 1 + 세션 2(유저별 리포트)
CREATE TABLE IF NOT EXISTS sessions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES users(id),
  mode               text NOT NULL,         -- 'boss' | 'battle'
  boss_id            text,
  room_id            uuid REFERENCES battle_rooms(id),
  scenario_variables jsonb,
  started_at         timestamptz NOT NULL,
  ended_at           timestamptz,
  end_reason         text,                  -- 'hang_up' | 'time_out' | 'silence' | 'clear'
  result             text,                  -- 'win' | 'lose' | 'abort'
  score              int,
  judge              jsonb,                 -- JudgeResult 전체
  CHECK ((mode = 'boss') = (boss_id IS NOT NULL)),
  CHECK ((mode = 'battle') = (room_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions (user_id, started_at DESC);

-- 6. 발화 — {speaker, text, t_start_ms} (규칙 #3)
CREATE TABLE IF NOT EXISTS utterances (
  id           bigserial PRIMARY KEY,
  session_id   uuid REFERENCES sessions(id),      -- 싱글
  room_id      uuid REFERENCES battle_rooms(id),  -- 배틀(서버 병합본)
  speaker_user uuid REFERENCES users(id),
  speaker      text NOT NULL,                     -- 'user' | 'boss'
  text         text NOT NULL,                     -- 온디바이스 STT 실시간본
  refined_text text,                              -- faster-whisper 정제본(FSD §5.2, 비동기)
  t_start_ms   int  NOT NULL,                     -- 통화 시작=0 상대 시각
  CHECK ((session_id IS NULL) <> (room_id IS NULL))
);
CREATE INDEX IF NOT EXISTS utterances_session_idx ON utterances (session_id, t_start_ms);
CREATE INDEX IF NOT EXISTS utterances_room_idx ON utterances (room_id, t_start_ms);

-- 7. LLM 로그 — QLoRA 증류 데이터 (FSD §6.4)
CREATE TABLE IF NOT EXISTS llm_logs (
  id         bigserial PRIMARY KEY,
  task       text NOT NULL,     -- 'boss_turn' | 'incremental' | 'final_judge' | 'scenario'
  model      text NOT NULL,
  session_id uuid,
  request    jsonb NOT NULL,
  response   jsonb NOT NULL,
  latency_ms int,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- P1: 인크리멘탈 심판 이벤트 (게이지·힌트·캐스터) — 관전 리플레이·판정 시비 대응
CREATE TABLE IF NOT EXISTS judge_events (
  room_id  uuid NOT NULL REFERENCES battle_rooms(id),
  seq      int  NOT NULL,
  at_ms    int  NOT NULL,       -- 통화 시작 기준
  payload  jsonb NOT NULL,      -- {momentum_delta, event, hint_a, hint_b, caster}
  PRIMARY KEY (room_id, seq)
);
