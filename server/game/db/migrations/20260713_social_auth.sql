-- 소셜 로그인 도입 (2026-07-13, 로그인 시스템 개편)
-- users에 provider/provider_id/email 추가, 닉네임은 온보딩에서 설정하므로 nullable.
-- 기존 유저 데이터는 리셋 합의 — TRUNCATE CASCADE로 진행·기록도 함께 비운다
-- (boss_progress·sessions·utterances·battle_players·battle_rooms. llm_logs는 유지).

BEGIN;

TRUNCATE users CASCADE;

ALTER TABLE users
  ADD COLUMN provider    text NOT NULL,
  ADD COLUMN provider_id text NOT NULL,
  ADD COLUMN email       text;

ALTER TABLE users ALTER COLUMN nickname DROP NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_provider_uniq UNIQUE (provider, provider_id);

COMMIT;
