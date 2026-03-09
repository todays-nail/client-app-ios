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
- Avoid overly verbose descriptions or unnecessary details.

## Commit Message Policy (Required)

- Use Conventional Commits format: `<type>(<scope>): <subject>`.
- Allowed `type`: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
- Disallowed `type`: `ci`, `perf`, `revert`.
- Keep `subject` concise and do not end with a period.
- Write the `subject` in Korean.
- If commit body is present, write it in Korean bullet format only.
- Commit body bullet count must be between 1 and 4.
- Footer should include `Refs: #<issue-number>` or `Closes: #<issue-number>` when applicable.

## Issue Conventions

- Create an issue before implementation for all development tasks.
- Minor edits that can be completed within 10 minutes (for example typo fixes) may be treated as exceptions.
- Use issue title types: `feat`, `fix`, `refactor`, `test`, `docs`, `hotfix`.
- Issue title format:
  - `[feat]: <한국어 제목>`
  - `[fix]: <한국어 제목>`
  - `[refactor]: <한국어 제목>`
  - `[test]: <한국어 제목>`
  - `[docs]: <한국어 제목>`
  - `[hotfix]: <한국어 제목>`
- The `type` must be lowercase.
- Write the issue title `subject` in Korean and keep it concise.
- Required issue body fields:
  - Background / Problem
  - Expected result or acceptance criteria (AC)
  - Scope (In scope / Out of scope)
  - Related links (screens, APIs, documents, logs, screenshots)
- `fix` and `hotfix` issues must include reproduction steps, expected result, actual result, and environment (OS/device/app version).
- For DB/API/requirement changes, include `shared-schema` issue/PR links and consistency check points in the issue body.
- PRs must be linked to related issues using `Closes #<issue-number>`.

## Branch Strategy (GitFlow Lite)

- Use only two long-lived branches: `main` and `develop`.
- `develop` is the default integration branch for the next app release.
- `main` is the production release branch for App Store submission.
- Use short-lived work branches:
  - `feat/<issue-number>-<slug>`
  - `fix/<issue-number>-<slug>`
  - `refactor/<issue-number>-<slug>`
  - `test/<issue-number>-<slug>`
  - `docs/<issue-number>-<slug>`
  - `hotfix/<issue-number>-<slug>`
- `feat/*`, `fix/*`, `refactor/*`, `test/*`, and `docs/*` branches must be created from `develop` and merged back into `develop`.
- `hotfix/*` branches must be created from `main` and merged back into `main`.
- Standard release flow is `develop -> main` via PR after stabilization.
- After every hotfix merged to `main`, create a back-merge PR from `main` to `develop`.
- Use squash merge as the default merge method.
- Do not use release branches. Releases are identified only by tags on `main`.

## Release Tag Policy

- Release management uses version tags, not release branches.
- iOS release tag format: `ios/v<MARKETING_VERSION>+<CURRENT_PROJECT_VERSION>` (for example `ios/v1.0+6`).
- Create annotated tags on the release commit merged into `main`.
- Legacy date tags (`rel-*`) are kept for reference only and must not be used as the current release standard.

## DB Governance (Required)

- DB schema and Supabase Edge Function changes must be handled only in `../shared-schema`.
- Changes to `infra/supabase/migrations`, `infra/supabase/functions`, and `infra/supabase/dashboard-singlefile` are prohibited in this repo. (blocked by CI)
- DB/API change PRs must include `shared-schema` issue/PR links and app impact classification (no impact / backward compatible / app change required).

## Project Discovery (Do This First)

- Check for a pinned Xcode version (commonly `.xcode-version`) and follow it if present.
- Prefer opening/using a workspace if it exists (`*.xcworkspace`), otherwise a project (`*.xcodeproj`).
- Handle DB/Function change requests in `../shared-schema` first, then reflect only API contract app-code changes in this repository.
- Do not require DB pull/push/diff as a task gate for app-only changes (Swift/UI/business logic).

## Supabase Operation Rules (infra)

- Run DB schema/migration/functions deployment commands only in `../shared-schema`.
- Do not run `supabase db push/pull/diff`, migration repair, or function deploy/check in this repository.
- Use DB access in this repository only for limited read-only checks when app-impact confirmation is necessary.
- Follow the DB deployment order from `shared-schema`: Expand -> App/Function reflection -> Contract.

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
- To avoid parallel build collisions, do not share one DerivedData path that creates a common `build.db` lock. Use a dedicated `-derivedDataPath` per task.
- Within the same task/thread, prefer reusing the same `-derivedDataPath` (and optionally `-clonedSourcePackagesDirPath`) across repeated builds so Xcode can reuse build and package caches.
- If concurrent builds are required, use different `-derivedDataPath` values or run builds sequentially.
- `scripts/ios-warning-gate.sh` also uses a temporary `-derivedDataPath` for Release/Debug builds to reduce global DerivedData accumulation.

## Verification (Required After Code Changes)

- Build (fast compile check): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -sdk iphonesimulator build`
- Unit tests (when logic changes): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:NailClientTests`
- UI tests (only when UI flow changes): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project NailClient/NailClient.xcodeproj -scheme NailClient -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:NailClientUITests`
- If the simulator name/OS does not exist on a machine, pick an installed one from: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available`
- CI requirement: keep a shared scheme committed at `NailClient/NailClient.xcodeproj/xcshareddata/xcschemes/NailClient.xcscheme`.
- If missing, open Xcode and mark `NailClient` scheme as Shared, then commit the generated `.xcscheme` file.

## Test Conventions (iOS)

- Default to `Swift Testing` for new unit and integration tests. Use `XCTest` for UI and performance tests.
- Keep the test mix weighted toward many unit tests, fewer integration tests, and only critical UI tests.
- Structure unit tests in clear arrange / act / assert flow and prefer protocol-based stub or spy injection.
- `Swift Testing` runs tests in parallel by default. Do not depend on execution order, shared mutable state, or implicit singleton state.
- If a test must touch shared global state, serialize it intentionally and leave a short reason next to the test.
- Make UI tests deterministic with launch arguments and environment values for routing, fixtures, and feature flags.
- Do not treat `XCTSkip` as the default answer for active UI flows. If the feature is expected to work, the test should fail visibly.
- Do not park tests behind `#if false`. If a temporary disable is unavoidable, leave the related issue number and recovery note next to it.
- Place new test files under feature or subsystem folders. Put shared builders, fixtures, spies, and helpers only under `TestSupport/`.

## Code Conventions

- Architecture: default to MVVM (especially for SwiftUI). Keep views thin; put logic in testable types.
- Swift concurrency: prefer `async/await`; keep UI updates on the main actor.
- Avoid force unwraps and forced casts unless you can justify safety locally.
- Prefer small, testable units. Keep business logic out of views.
- Prefer the simplest implementation that satisfies the current requirement.
- Remove duplication only when it materially reduces maintenance cost.
- Avoid abstractions or generalizations for unproven future needs.

## Review Guidelines

- Do not log secrets, API keys, access tokens, or personal data.
- Never embed `OPENAI_API_KEY` (or any server secret) in the iOS app. All model calls must go through a server you control.
- Validate error handling and cancellation for async work (networking, image upload, AI generation).
- Flag anything that would break CI or local builds (missing schemes, missing config files, or unchecked dependency changes).

## Official References

- Codex Worktrees: <https://developers.openai.com/codex/app/worktrees/>
- Codex Local Environments: <https://developers.openai.com/codex/app/local-environments/>
- Git Worktree manual: <https://git-scm.com/docs/git-worktree>
