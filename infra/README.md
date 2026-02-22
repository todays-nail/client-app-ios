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

## 지도/지역 시크릿 계약
- `VWORLD_API_KEY` (필수): `regions-sync-vworld.sh`에서 행정구역 경계 데이터 수집 시 사용.
- `NAVER_MAPS_REST_CLIENT_ID` (선택): 추후 Geocoding/Reverse Geocoding 서버 호출 확장 시 사용.
- `NAVER_MAPS_REST_CLIENT_SECRET` (선택): 추후 Geocoding/Reverse Geocoding 서버 호출 확장 시 사용.

설정 예시:
- `supabase secrets set VWORLD_API_KEY=...`
- `supabase secrets set NAVER_MAPS_REST_CLIENT_ID=...`
- `supabase secrets set NAVER_MAPS_REST_CLIENT_SECRET=...`
