# Supabase (Moved)

`client-app-ios/infra/supabase`의 DB migration/Edge Functions 소스는
`../shared-schema` 저장소로 이관되었습니다.

## Canonical Source
- `../shared-schema/migrations`
- `../shared-schema/supabase/functions`

## 이 저장소 정책
- `client-app-ios`에서는 위 경로의 소스를 직접 수정/배포하지 않습니다.
- 앱은 Supabase Edge API 소비자 역할만 수행합니다.
- API 계약 변경 시 앱 코드에서 필요한 범위만 업데이트합니다.
