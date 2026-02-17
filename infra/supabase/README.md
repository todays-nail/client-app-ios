# Supabase Edge Functions (오늘 네일)

이 폴더는 iOS 앱이 직접 DB/Supabase Auth를 사용하지 않고, **Edge Function API**만 호출하는 아키텍처를 위한 백엔드 코드입니다.

## 위치
- `client-app-ios/infra/supabase`
- Supabase CLI는 **`client-app-ios/infra`에서 실행**하는 것을 기준으로 합니다. (현재 디렉토리 기준 `./supabase/*`를 찾기 때문)
- 공용 migration canonical은 `client-app-ios/shared-schema/migrations` (git submodule)입니다.
- `infra/supabase/migrations`는 실행 대상 디렉토리이며, 아래 스크립트로 동기화합니다:
  - `bash infra/scripts/db-sync-from-shared.sh`
  - 검증 전용: `bash infra/scripts/db-sync-from-shared.sh --check`
  - (`cd infra` 후) `npm run db:sync:from-shared`, `npm run db:sync:check` 사용 가능

## DB 운영 정책
- `ios-dev`, `web-dev`, `shared-staging/prod` 분리 운영을 기본값으로 사용합니다.
- 이 저장소에서 직접 push 가능한 대상은 `ios-dev`만입니다.
- `shared-staging/prod` 직접 push는 금지하고, `shared-schema` 저장소 CI에서만 반영합니다.
- 환경 변수 계약:
  - `SUPABASE_DB_URL_IOS_DEV`
  - `SUPABASE_DB_URL_WEB_DEV`
  - `SUPABASE_DB_URL_SHARED_STAGING`
  - `SUPABASE_DB_URL_SHARED_PROD`

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
supabase functions deploy nail-gen-refine-request --no-verify-jwt
supabase functions deploy nail-gen-status --no-verify-jwt
supabase functions deploy nail-gen-worker --no-verify-jwt
```

## SQL Migration 반영 (예시)
```bash
cd /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra
npm run db:check
npm run db:push:dev
```

`db-check.sh`는 기본적으로 `--linked`를 시도하고, 인증 이슈(`cli_login_postgres` / `Circuit breaker open`)가 나면 `SUPABASE_DB_URL_IOS_DEV`로 자동 fallback 합니다.

## Migration 파일 규칙
- 전환 시점(`20260218000000`) 이후 신규 파일명:
  - `YYYYMMDDHHMMSS_<team>_<description>.sql`
  - `<team>`은 `ios` 또는 `web`

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
