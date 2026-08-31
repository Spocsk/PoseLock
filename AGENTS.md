# PoseLock

iOS app built with Swift / SwiftUI. The GitHub remote is `https://github.com/Spocsk/PoseLock`.

## Project layout

- SwiftUI app sources will live at the repository root (Xcode project).
- Cloud environment config lives in `.cursor/` (`Dockerfile`, `environment.json`).

## Cursor Cloud specific instructions

Cloud agents run on Ubuntu. They can edit this repository, commit, and open pull requests. They cannot run Xcode, the iOS Simulator, or UIKit/SwiftUI binaries.

When working in the cloud:

- Write and refactor Swift / SwiftUI as usual.
- Do not try to `xcodebuild`, `xcrun`, `simctl`, or open `.xcodeproj`.
- Prefer small, reviewable diffs and describe how a human would verify on a Mac with Xcode 15+.
- Keep secrets out of the repo. Use Cursor Secrets if credentials are needed later.
- The `install` command in `.cursor/environment.json` is a smoke check only. There is no package install step yet.
