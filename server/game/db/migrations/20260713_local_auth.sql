-- 일반(이메일+비밀번호) 가입 지원 (2026-07-13, 소셜 로그인에 추가)
-- local 계정은 provider='local', provider_id=이메일(소문자) — 기존 UNIQUE 제약이 중복 가입 방지.
-- 데이터 리셋 없음.

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash text;  -- bcrypt, local 계정만 사용
