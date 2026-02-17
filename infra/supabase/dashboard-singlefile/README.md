# Supabase Dashboard 배포용 (단일 파일) Edge Functions

Supabase Dashboard에서 Edge Function을 만들 때, 멀티파일(`_shared/*`) import 구성이 번거로울 수 있어 단일 파일 버전을 제공합니다.

## 사용법
1. Supabase Dashboard > Edge Functions
2. 아래 함수들을 각각 Create
- `auth-kakao`
- `auth-refresh`
- `auth-logout`
- `users-me`
- `feed-list`
- `feed-detail`
3. 각 함수의 `index.ts`에 아래 파일 내용을 그대로 붙여넣고 Deploy
4. 각 함수 설정에서 `Verify JWT`는 OFF (우리는 Supabase Auth JWT가 아니라 앱 JWT를 검증)

## Secrets (Edge Functions > Secrets)
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APP_JWT_SECRET`
- `REFRESH_TOKEN_PEPPER`
