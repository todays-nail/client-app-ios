# Operations Docs Index

## Start Here

- Preview/workaround notes: `docs/ios-preview-guide.md`
- Warning policy and baseline workflow: `docs/ios-warning-gate.md`
- Release checklist for social login changes: `docs/social-login-release-checklist.md`
- Hackathon submission reference copy: `docs/hackathon-submission.md`

## When To Read What

- If Xcode preview behavior changes, start with `docs/ios-preview-guide.md`.
- If CI or local builds fail because of warnings, start with `docs/ios-warning-gate.md`.
- If a release touches Apple/Kakao/Google login flows, use `docs/social-login-release-checklist.md`.
- If you need the current hackathon submission wording or external reference links, use `docs/hackathon-submission.md`.

## Asset Note

- The active app icon build setting is `ASSETCATALOG_COMPILER_APPICON_NAME = todays_nail`.
- `NailClient/NailClient/todays_nail.icon` is tracked separately from the active `Assets.xcassets/todays_nail.appiconset`.
- Treat `todays_nail.icon` as a retained asset source/reference bundle unless a dedicated cleanup task verifies it is safe to remove.
