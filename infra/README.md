# Infra

이 폴더는 iOS 앱에서 직접 쓰지 않는 인프라/백엔드 설정(예: Supabase Edge Functions, DB migrations)을 관리합니다.

## Supabase
- 코드 위치: `infra/supabase`
- 배포: `infra/supabase/README.md` 참고
- 운영 스크립트:
  - `bash infra/scripts/db-sync-from-shared.sh` (shared-schema -> infra/supabase/migrations 동기화)
  - `bash infra/scripts/db-check.sh` (`migration list` + `db push --dry-run` + `db diff` with fallback)
  - `bash infra/scripts/db-push-dev.sh` (`shared-staging` DB push)
- npm script alias (`cd infra` 기준):
  - `npm run db:sync:from-shared`
  - `npm run db:check`
  - `npm run db:push:dev`
