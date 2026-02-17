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

## Project Discovery (Do This First)

- Check for a pinned Xcode version (commonly `.xcode-version`) and follow it if present.
- Prefer opening/using a workspace if it exists (`*.xcworkspace`), otherwise a project (`*.xcodeproj`).
- If the repo uses submodules, run: `git submodule update --init --recursive`
- Before starting any implementation task, sync DB schema from Supabase from the infra directory:
  - `supabase migration list --workdir /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra`
  - `supabase db pull --workdir /Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/infra`
- If `supabase db pull` fails (not logged in / project not linked / network issue), stop and report the reason before continuing code changes.
- Do not run `supabase migration repair` unless the user explicitly approves it for the current incident.

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
