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
- 개발/통합 단계에서는 `shared-staging` 단일 DB를 공용으로 사용합니다.
- 이 저장소에서도 `shared-staging`으로 직접 push 가능합니다.
- `shared-schema` 저장소 CI도 동일한 `shared-staging/prod`를 사용합니다.
- 환경 변수 계약:
  - `SUPABASE_DB_URL_SHARED_STAGING`
  - `SUPABASE_DB_URL_SHARED_PROD`
  - `SUPABASE_DB_URL_IOS_DEV` (legacy optional)
  - `SUPABASE_DB_URL_WEB_DEV` (legacy optional)

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
supabase functions deploy users-delete --no-verify-jwt
supabase functions deploy feed-list --no-verify-jwt
supabase functions deploy regions-list --no-verify-jwt
supabase functions deploy feed-detail --no-verify-jwt
supabase functions deploy feed-like --no-verify-jwt
supabase functions deploy shop-search --no-verify-jwt
supabase functions deploy shop-recommend --no-verify-jwt
supabase functions deploy shop-detail --no-verify-jwt
supabase functions deploy reservation-slots --no-verify-jwt
supabase functions deploy reservation-create --no-verify-jwt
supabase functions deploy reservation-list --no-verify-jwt
supabase functions deploy nail-gen-upload-url --no-verify-jwt
supabase functions deploy nail-gen-request --no-verify-jwt
supabase functions deploy nail-gen-refine-request --no-verify-jwt
supabase functions deploy nail-gen-status --no-verify-jwt
supabase functions deploy nail-gen-list --no-verify-jwt
supabase functions deploy nail-gen-delete --no-verify-jwt
supabase functions deploy quote-request-create --no-verify-jwt
supabase functions deploy nail-gen-worker --no-verify-jwt
supabase functions deploy profile-style-insight --no-verify-jwt

supabase functions list --project-ref twahqxjhyocyqrmtjbdf
npm run functions:check:deployed
npm run functions:check:auth-config
```

## 인증 방식/검증 정책
`verify_jwt`는 Supabase 게이트웨이 레벨 검증 설정이고, 함수 내부 검증(`verifyAccessJwt`, `x-worker-secret` 등)과는 별개입니다.  
현재 아키텍처에서는 앱 호출 함수의 `verify_jwt`를 `false`로 두고, 함수 내부 검증을 필수로 유지합니다.

| 인증 모드 | 함수 | inbound 인증 방식 | 기대 `verify_jwt` |
|---|---|---|---|
| `app_access_jwt` | `users-me`, `users-delete`, `feed-list`, `feed-detail`, `feed-like`, `regions-list`, `shop-search`, `shop-recommend`, `shop-detail`, `reservation-slots`, `reservation-create`, `reservation-list`, `nail-gen-upload-url`, `nail-gen-request`, `nail-gen-refine-request`, `nail-gen-status`, `nail-gen-list`, `nail-gen-delete`, `quote-request-create`, `profile-style-insight` | `Authorization: Bearer <APP_ACCESS_TOKEN>` + 내부 `verifyAccessJwt` | `false` |
| `refresh_token` | `auth-refresh`, `auth-logout` | 본문 `refreshToken + deviceId` 검증 | `false` |
| `kakao_exchange` | `auth-kakao` | 본문 `kakaoAccessToken + deviceId` 검증 | `false` |
| `worker_secret` | `nail-gen-worker` | 헤더 `x-worker-secret` 검증 | `false` |

정책 드리프트 점검:
- 함수 배포 여부: `npm run functions:check:deployed`
- 인증 설정(`verify_jwt`) 점검: `npm run functions:check:auth-config`

## 운영 검증 시나리오
1. 자동로그인 정상 흐름
- `auth-refresh`가 `200`을 반환한 뒤 `users-me`가 `200`을 반환해야 합니다.

2. 음수 케이스
- 잘못된 access token으로 `users-me` 호출 시 `401`이어야 합니다.
- `x-worker-secret` 없이 `nail-gen-worker` 호출 시 `401`이어야 합니다.

## SQL Migration 반영 (예시)
```bash
cd /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra
npm run db:check
npm run db:push:dev
```

`db-check.sh`는 기본적으로 `--linked`를 시도하고, 인증 이슈(`cli_login_postgres` / `Circuit breaker open`)가 나면 `SUPABASE_DB_URL_SHARED_STAGING`으로 자동 fallback 합니다. Docker가 없으면 `db diff` 단계는 자동 스킵됩니다.

## Migration 파일 규칙
- 전환 시점(`20260218000000`) 이후 신규 파일명:
  - `YYYYMMDDHHMMSS_<team>_<description>.sql`
  - `<team>`은 `ios` 또는 `web`

## 피드 API 샘플 호출
```bash
# feed-list
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-list?limit=20&category=all' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# feed-list (region filter)
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/feed-list?limit=20&category=all&region_id=<REGION_UUID>&include_descendants=true' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# regions-list
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/regions-list' \
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

# reservation-slots
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/reservation-slots?reference_id=11111111-1111-4111-8111-111111111111&from_date=2026-02-18&days=7' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# reservation-create
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/reservation-create' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"reference_id":"11111111-1111-4111-8111-111111111111","slot_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}'

# reservation-list (upcoming)
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/reservation-list?segment=upcoming&limit=20' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# reservation-list (past)
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/reservation-list?segment=past&limit=20' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# nail-gen-list (completed only)
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/nail-gen-list?limit=20' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'

# nail-gen-delete
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/nail-gen-delete' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"job_id":"11111111-1111-4111-8111-111111111111"}'

# quote-request-create (region target)
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/quote-request-create' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"job_id":"11111111-1111-4111-8111-111111111111","target_type":"REGION","region_id":"22222222-2222-4222-8222-222222222222"}'

# quote-request-create (shop target)
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/quote-request-create' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"job_id":"11111111-1111-4111-8111-111111111111","target_type":"SHOP","shop_id":"33333333-3333-4333-8333-333333333333"}'

# profile-style-insight
curl -i 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/profile-style-insight?post_limit=12' \
  -H 'Authorization: Bearer <APP_ACCESS_TOKEN>'
```

## Nail AI Worker 스케줄러
`nail-gen-worker`는 내부 호출용 함수입니다. 1분 간격 스케줄러에서 아래처럼 호출하세요.

```bash
curl -i -X POST 'https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1/nail-gen-worker' \
  -H 'x-worker-secret: <NAIL_GEN_WORKER_SECRET>'
```

권장: Edge Function Scheduler(또는 외부 cron)에서 분당 1회 실행

## Nail AI 생성 모델 정책
- OpenAI endpoint: `POST /v1/images/edits`
- Image model: `gpt-image-1.5`
- 생성 방식: hand + reference 2개 입력 이미지를 편집(`images[]`)
- 품질 정책: `quality=high`, `size=auto`, `output_format=png`
- 참고: `NAIL_GEN_PROFILE`는 현재 품질 분기 기준으로 사용하지 않습니다.

## iOS 호출 Base URL
`https://<project-ref>.supabase.co/functions/v1`
