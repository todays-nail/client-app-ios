# Infra

이 폴더는 iOS 앱 보조 인프라 문서/운영 메모를 관리합니다.

## DB/Functions Governance
- DB schema migration과 Supabase Edge Functions의 canonical 소스는 `../shared-schema` 입니다.
- 이 저장소(`client-app-ios`)에서는 DB/Functions 소스를 직접 수정하지 않습니다.
- DB/API 계약이 바뀌면 앱 코드(`NailClient`)만 필요한 범위로 반영합니다.

## 작업 원칙
- DB/Functions 관련 이슈/PR은 `shared-schema`에서 생성/진행합니다.
- 이 저장소 PR에는 대응되는 `shared-schema` 이슈/PR 링크를 남깁니다.
