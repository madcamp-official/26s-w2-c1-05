# 소셜 로그인 설정 가이드 (2026-07-13 도입)

앱은 브라우저 OAuth + loopback 방식(Android·Windows 공통)이라 클라이언트 쪽 키 설정이 없다.
**모든 키는 서버(`server/game/.env`)에만** 넣는다. 아래 순서대로 하면 끝.

## 1. 서버 준비

```bash
cd server/game
pip install -r requirements.txt   # PyJWT 추가됨
psql "$DATABASE_URL" -f db/migrations/20260713_social_auth.sql   # ⚠ 유저 데이터 리셋됨
```

`.env`에 추가 (`.env.example` 참고):

```
JWT_SECRET=<아무 긴 랜덤 문자열: openssl rand -hex 32>
PUBLIC_BASE_URL=https://graceheeseo.madcamp-kaist.org
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
KAKAO_REST_API_KEY=...
```

## 2. Google Cloud Console

1. https://console.cloud.google.com → 프로젝트 생성(또는 기존) → **APIs & Services → OAuth consent screen**
   - User type: External, 테스트 모드면 팀원 이메일을 테스트 사용자로 등록
2. **Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application** (앱이 아니라 서버가 콜백을 받으므로)
   - Authorized redirect URIs: `https://graceheeseo.madcamp-kaist.org/auth/google/callback`
3. 발급된 Client ID/Secret → `.env`

## 3. Kakao Developers

1. https://developers.kakao.com → 애플리케이션 추가
2. **앱 키 → REST API 키** → `.env`의 `KAKAO_REST_API_KEY`
3. **제품 설정 → 카카오 로그인 → 활성화 ON**
   - Redirect URI 등록: `https://graceheeseo.madcamp-kaist.org/auth/kakao/callback`
4. **동의항목 → 카카오계정(이메일)** 을 "선택 동의"로 설정
   - 이메일 동의항목을 못 켜는 앱이면 `.env`에 `KAKAO_SCOPE=` (빈 값) 추가 — 이메일 없이 로그인만 됨
5. (선택) 보안 → Client Secret 활성화 시 `KAKAO_CLIENT_SECRET`도 설정

## 4. 동작 확인

```bash
# 서버 재시작 후, 브라우저에서 직접:
https://graceheeseo.madcamp-kaist.org/auth/google/start?port=53682
# → 구글 로그인 → "127.0.0.1:53682 연결 거부" 화면이 뜨면 정상
#   (앱이 리스너를 열고 있을 때만 마지막 단계가 성공)
```

앱 온보딩 3단계에서 Google/카카오 버튼 → 브라우저 로그인 → 앱 복귀가 전체 플로우.

## 계약 요약 (서버 auth.py ↔ 앱 auth_service.dart)

- `GET /auth/{provider}/start?port=` → 프로바이더로 302
- 콜백 처리 후 `http://127.0.0.1:{port}/callback?token=&user_id=&is_new=&nickname?=` 으로 302
- 이후 REST는 `Authorization: Bearer {token}`, WS는 `?token=` 쿼리
- `GET/PATCH/DELETE /users/me` — 조회·닉네임 변경(409=중복)·탈퇴
