# Supabase Edge Functions (오늘 네일)

이 폴더는 iOS 앱이 직접 DB/Supabase Auth를 사용하지 않고, **Edge Function API**만 호출하는 아키텍처를 위한 백엔드 코드입니다.

## 위치
- `client-app-ios/infra/supabase`
- Supabase CLI는 **`client-app-ios/infra`에서 실행**하는 것을 기준으로 합니다. (현재 디렉토리 기준 `./supabase/*`를 찾기 때문)

## 필수 Secrets (Supabase Dashboard > Edge Functions > Secrets)
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APP_JWT_SECRET`
- `REFRESH_TOKEN_PEPPER`

## Deploy (예시)
아래 함수들은 Supabase Auth JWT 검증을 끄고(`--no-verify-jwt`), **우리 앱 Access JWT만** 검증합니다.

```bash
cd /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra

supabase login
supabase link --project-ref twahqxjhyocyqrmtjbdf

supabase functions deploy auth-kakao --no-verify-jwt
supabase functions deploy auth-refresh --no-verify-jwt
supabase functions deploy auth-logout --no-verify-jwt
supabase functions deploy users-me --no-verify-jwt
```

## iOS 호출 Base URL
`https://<project-ref>.supabase.co/functions/v1`
