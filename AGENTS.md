# AGENTS.md (iOS)

This file is for team-shared conventions only. Keep personal workflow/tool preferences in user-level config.

## Project Snapshot

- App: `NailClient` (SwiftUI)
- Xcode project: `NailClient/NailClient.xcodeproj`
- Test targets: `NailClientTests`, `NailClientUITests`

## Working Agreements

- Default response language: Korean.
- If the request is ambiguous or high-impact (wide refactor, new dependency, signing/capabilities), propose the approach + changed files first and confirm before implementing.
- Keep changes small and verifiable. If you create new files, `git add` them early so they are not lost.
- Prefer Swift + Xcode workflows. Do not commit local Xcode state (for example `xcuserdata/`, `DerivedData/`).
- Prefer Swift Package Manager. Do not introduce CocoaPods/Carthage unless the repo already uses them (ask first).
- Ask before changing signing/bundle identifiers/capabilities or introducing new production dependencies.

## Issue Conventions

- 모든 개발 작업은 이슈 생성 후 진행한다. (단순 오탈자/문구 수정 등 10분 이내 경미 작업은 예외 가능)
- 이슈 타입은 `Bug`, `Feature`, `Task` 3가지를 기본으로 사용한다.
- 이슈 제목 규칙:
  - `[Bug] <영역>: <증상>`
  - `[Feature] <영역>: <요구사항/개선점>`
  - `[Task] <영역>: <작업 내용>`
- 이슈 본문 필수 정보:
  - 배경/문제
  - 기대 결과 또는 수용 기준(AC)
  - 범위(In scope / Out of scope)
  - 관련 링크(화면, API, 문서, 로그, 스크린샷 등)
- 버그 이슈는 반드시 `재현 절차`, `기대 결과`, `실제 결과`, `환경(OS/기기/앱 버전)`을 포함한다.
- DB 스키마 변경은 `todays-nail/shared-schema` 저장소에서만 관리하고, 이 저장소에는 sync 결과만 반영한다.
- DB/API/요구사항 변경 이슈는 `shared-schema` 요청 이슈 링크와 정합성 체크 포인트를 본문에 남긴다.
- PR은 반드시 관련 이슈를 연결한다. (`Closes #<issue-number>`)

## Branch Strategy (GitFlow Lite)

- 장기 브랜치는 `main`, `develop` 두 개만 사용한다.
- 기본 개발 루트 브랜치는 `develop`이다.
- 일반 작업 브랜치:
  - `feature/<issue-number>-<slug>`
  - `bugfix/<issue-number>-<slug>`
  - `task/<issue-number>-<slug>`
- 일반 작업 브랜치는 `develop`에서 분기하고 `develop`으로 PR을 생성한다.
- 릴리즈 브랜치: `release/ios-v<MARKETING_VERSION>+<CURRENT_PROJECT_VERSION>` 형식으로 `develop`에서 분기하고 `main`으로 PR을 생성한다.
- 긴급 수정 브랜치: `hotfix/<issue-number>-<slug>` 형식으로 `main`에서 분기하고 `main`으로 PR을 생성한다.
- 기본 머지 방식은 `Squash merge`를 사용한다.
- `main`에 반영된 릴리즈/핫픽스 변경사항은 반드시 `develop`으로 역머지(back-merge) PR을 생성한다.

## Definition of Done (GitHub Only)

- PR 본문에 `Closes #<issue-number>`를 반드시 포함한다.
- PR 본문에 `Summary`, `Scope (In scope / Out of scope)`, `Validation Results`, `Risk & Rollback` 섹션을 반드시 작성한다.
- 검증 결과에는 실제 실행한 빌드/테스트 명령과 결과를 명시한다.
- DB 스키마 변경이 포함된 PR은 `https://github.com/todays-nail/shared-schema/issues/<number>` 링크를 반드시 포함한다.
- 브랜치 보호 규칙에서 `main`, `develop`에 `policy-gate`, `Supabase Schema Validation`, `ios-warning-gate`를 필수 체크로 설정하고 direct push를 차단한다.
- 관련 이슈/PR 링크는 GitHub 기준으로 남기고, 완료 기준은 GitHub 이슈/PR 상태로 판정한다.

## Release Tag Policy

- Release 기준은 브랜치가 아닌 버전 태그를 사용한다.
- iOS 릴리즈 태그 형식: `ios/v<MARKETING_VERSION>+<CURRENT_PROJECT_VERSION>` (예: `ios/v1.0+6`).
- 태그는 `main`에 머지된 릴리즈 커밋에 annotated tag로 생성한다.
- 기존 날짜 태그(`rel-*`)는 레거시 참조용으로만 유지하고 신규 릴리즈 기준으로 사용하지 않는다.

## Project Discovery (Do This First)

- Check for a pinned Xcode version (commonly `.xcode-version`) and follow it if present.
- Prefer opening/using a workspace if it exists (`*.xcworkspace`), otherwise a project (`*.xcodeproj`).
- For app-only code changes (Swift/UI/business logic), do **not** block work on `supabase db pull`.
- Run Supabase checks for every DB-facing change (`infra/supabase/migrations`, `infra/supabase/functions`, DB contract docs, DB URL/README 수정).  
  - 기본 순서: `bash infra/scripts/db-sync-from-shared.sh --check` → `bash infra/scripts/db-check.sh`
- 앱 코드만 바꾸는 작업에서 `supabase db pull`이 필요하지 않도록 강제하고, DB-facing 변경이 아닌 한 `db pull`을 일일이 요구하지 않는다.
- Shared `public` schema source of truth is `todays-nail/shared-schema` repository.  
  Keep `infra/supabase/migrations` in full sync via `db-sync-from-shared.sh` (remote fetch + pinned `SHARED_SCHEMA_REF`).

## Supabase Operation Rules (infra)

- All Supabase commands must run from `client-app-ios/infra` (or with `--workdir` pointing there).
- 개발/통합 단계에서는 `shared-staging` 단일 DB를 공용으로 사용.
- 이 저장소에서도 `shared-staging`으로 직접 `db push` 허용.
- `shared-prod` 환경은 유지한다. 해커톤/초기 단계에서는 승인자(`Required reviewers`)를 비워둘 수 있고, 운영 전환 시 1명 이상 권장한다.
- Default verification order for migration work:
  - `bash infra/scripts/db-check.sh`
  - `bash infra/scripts/shared-schema-branch-check.sh`로 고정된 `SHARED_SCHEMA_REF`가 fetch 가능한지 확인 가능
  - `bash infra/scripts/db-check.sh`는 `infra/.env`를 자동 로드한다.
  - `bash infra/scripts/db-check.sh`는 머신 단위 락(`/tmp/todays-nail-shared-db-check.lock`)으로 동시 실행을 차단해 순차 실행을 강제한다.
  - `bash infra/scripts/db-check.sh`는 `db diff`에서 shadow DB 포트 충돌 시 `supabase stop --project-id <project_id>`를 1회 실행 후 재시도한다.
  - `bash infra/scripts/db-push-dev.sh` (필요 시)
- Use `supabase db pull` only when a real schema import/reconcile is needed, not as a per-task gate.
- If `--linked` fails with `cli_login_postgres` / `Circuit breaker open`:
  - set DB password env: `export SUPABASE_DB_PASSWORD='<DB_PASSWORD>'`
  - re-link: `supabase link --project-ref twahqxjhyocyqrmtjbdf --password "$SUPABASE_DB_PASSWORD"`
  - retry once after 5-15 minutes (avoid repeated immediate retries)
  - if still failing, use `--db-url` for `db pull/push/diff`
- Do not run `supabase migration repair` unless the user explicitly approves it for the current incident and target versions.
- Docker가 실행 중이 아니면 `db-check.sh`에서 `db diff`는 자동 스킵한다.
- 환경 변수 계약:
  - `SUPABASE_DB_URL_SHARED_STAGING`
  - `SUPABASE_DB_URL_SHARED_PROD`
  - `SUPABASE_DB_URL_IOS_DEV` (legacy optional)
  - `SUPABASE_DB_URL_WEB_DEV` (legacy optional)
- migration 파일명 규칙(전환 시점 이후): `YYYYMMDDHHMMSS_<team>_<description>.sql` (`team`: `ios`/`web`)

## Codex Worktree Workflow (Recommended)

- Worktrees require a Git repository.
- In Codex app, start a new thread with **Worktree**, choose a starting branch, then run the task.
- Codex-created worktrees start in detached HEAD by default; create a branch only when you want to keep that line of work.
- If you verify in the worktree, use **Create branch here** and continue there. If you verify in your main checkout, use **Sync with local**.
- Git branch constraint: one branch cannot be checked out in multiple worktrees at the same time (including the main checkout).
- Keep shared worktree setup/actions in `.codex/` so teammates can reuse the same setup.
- Use setup scripts for dependencies/build steps needed in fresh worktree directories.
- One task per worktree. Do not mix unrelated features in a single worktree.
- Prefer CLI hygiene when managing linked worktrees:
  - `git worktree list`
  - `git worktree add -d ../worktrees/<task-name> <base-branch>` (detached experiment)
  - `git worktree add -b <feature-branch> ../worktrees/<task-name> <base-branch>` (branch-based work)
  - `git worktree remove ../worktrees/<task-name>` when done
  - `git worktree prune` to clean stale metadata
  - if paths were moved manually, run `git worktree repair`
- Do not delete worktree directories manually when possible; remove them via `git worktree remove`.

## Build And Test (iOS)

- Toolchain must be Xcode (not Command Line Tools only). Check: `xcode-select -p` and `xcodebuild -version`. If `xcodebuild` fails, select Xcode (example): `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Prefer running builds/tests with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` to avoid CLT-only toolchains.
- Do not run `swift test` for iOS app test runs. Use `xcodebuild` + a simulator instead.
- List schemes: `xcodebuild -list -project NailClient/NailClient.xcodeproj`
- 병렬 빌드 충돌을 피하기 위해 동일한 DerivedData 경로를 공유해 `build.db` 잠금을 만들지 말고, 사용자 작업별 빌드는 `-derivedDataPath`를 고정 경로로 분리해 실행한다.
- 동시 빌드가 필요할 때는 서로 다른 `-derivedDataPath`를 사용하거나, 선행 빌드가 끝난 뒤 순차적으로 실행한다.
- `scripts/ios-warning-gate.sh`도 Release/Debug 빌드에 임시 `-derivedDataPath`를 사용해 전역 DerivedData 누적을 줄인다.

## Verification (Required After Code Changes)

- Build (fast compile check): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -sdk iphonesimulator build`
- Unit tests (when logic changes): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:NailClientTests`
- UI tests (only when UI flow changes): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:NailClientUITests`
- If the simulator name/OS does not exist on a machine, pick an installed one from: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available`
- CI requirement: keep a shared scheme committed at `NailClient/NailClient.xcodeproj/xcshareddata/xcschemes/NailClient.xcscheme`.
- If missing, open Xcode and mark `NailClient` scheme as Shared, then commit the generated `.xcscheme` file.

## Code Conventions

- Architecture: default to MVVM (especially for SwiftUI). Keep views thin; put logic in testable types.
- Swift concurrency: prefer `async/await`; keep UI updates on the main actor.
- Avoid force unwraps and forced casts unless you can justify safety locally.
- Prefer small, testable units. Keep business logic out of views.

## Review Guidelines

- Do not log secrets, API keys, access tokens, or personal data.
- Never embed `OPENAI_API_KEY` (or any server secret) in the iOS app. All model calls must go through a server you control.
- Validate error handling and cancellation for async work (networking, image upload, AI generation).
- Flag anything that would break CI or local builds (missing schemes, missing config files, or unchecked dependency changes).

## Official References

- Codex Worktrees: <https://developers.openai.com/codex/app/worktrees/>
- Codex Local Environments: <https://developers.openai.com/codex/app/local-environments/>
- Git Worktree manual: <https://git-scm.com/docs/git-worktree>
