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
- `OPENAI_API_KEY`
- `NAIL_GEN_WORKER_SECRET`

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
supabase functions deploy feed-list --no-verify-jwt
supabase functions deploy feed-detail --no-verify-jwt
supabase functions deploy feed-like --no-verify-jwt
supabase functions deploy nail-gen-upload-url --no-verify-jwt
supabase functions deploy nail-gen-request --no-verify-jwt
supabase functions deploy nail-gen-status --no-verify-jwt
supabase functions deploy nail-gen-worker --no-verify-jwt
```

## SQL Migration 반영 (예시)
```bash
cd /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra
supabase db push
```

## 피드 API 샘플 호출
```bash
# feed-list
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-list?limit=20&category=all' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# feed-detail
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-detail?post_id=11111111-1111-4111-8111-111111111111' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# feed-like (save)
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-like' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"post_id":"11111111-1111-4111-8111-111111111111"}'

# feed-like (cancel)
curl -i -X DELETE 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-like' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"post_id":"11111111-1111-4111-8111-111111111111"}'
```

## Nail AI Worker 스케줄러
`nail-gen-worker`는 내부 호출용 함수입니다. 1분 간격 스케줄러에서 아래처럼 호출하세요.

```bash
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/nail-gen-worker' \
  -H 'x-worker-secret: <NAIL_GEN_WORKER_SECRET>'
```

권장: Edge Function Scheduler(또는 외부 cron)에서 분당 1회 실행

## iOS 호출 Base URL
`https://<project-ref>.supabase.co/functions/v1`
