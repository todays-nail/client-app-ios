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
- DB/API/요구사항 변경 이슈는 `shared-schema` 이슈/PR 링크와 정합성 체크 포인트를 본문에 남긴다.
- PR은 반드시 관련 이슈를 연결한다. (`Closes #<issue-number>`)

## Release Tag Policy

- Release 기준은 브랜치가 아닌 버전 태그를 사용한다.
- iOS 릴리즈 태그 형식: `ios/v<MARKETING_VERSION>+<CURRENT_PROJECT_VERSION>` (예: `ios/v1.0+6`).
- 태그는 `main`에 머지된 릴리즈 커밋에 annotated tag로 생성한다.
- 기존 날짜 태그(`rel-*`)는 레거시 참조용으로만 유지하고 신규 릴리즈 기준으로 사용하지 않는다.

## DB Governance (Required)

- DB schema 및 Supabase Edge Function 변경은 `../shared-schema` 저장소에서만 수행한다.
- 이 저장소에서 `infra/supabase/migrations`, `infra/supabase/functions`, `infra/supabase/dashboard-singlefile` 변경은 금지한다. (CI에서 차단)
- DB/API 변경 PR에는 `shared-schema` 이슈/PR 링크와 앱 영향 범위(무영향/호환/수정 필요)를 반드시 남긴다.

## Project Discovery (Do This First)

- Check for a pinned Xcode version (commonly `.xcode-version`) and follow it if present.
- Prefer opening/using a workspace if it exists (`*.xcworkspace`), otherwise a project (`*.xcodeproj`).
- DB/Function 변경 요청은 먼저 `../shared-schema`에서 처리하고, 이 저장소에는 API 계약 반영 앱 코드만 반영한다.
- 앱 코드 변경(Swift/UI/business logic)에는 DB pull/push/diff를 작업 게이트로 요구하지 않는다.

## Supabase Operation Rules (infra)

- DB schema/migration/functions 배포 커맨드는 `../shared-schema`에서만 실행한다.
- 이 저장소에서 `supabase db push/pull/diff`, migration repair, function deploy/check를 실행하지 않는다.
- 앱 영향 확인을 위한 read-only 조회가 필요할 때만 제한적으로 DB를 조회한다.
- DB 변경 배포 기본 순서는 `shared-schema` 기준으로 Expand -> App/Function 반영 -> Contract 를 따른다.

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
