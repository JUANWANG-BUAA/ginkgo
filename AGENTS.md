# Repository Guidelines

## Current Development Focus (2026-10-22)

Android is the current primary development platform, using the existing Flutter + Rust stack. Prioritize user-visible features and UX/UI improvements with reliability safeguards; do not require a full technical-debt cleanup first. The first iteration covers Today 2.0, homework-to-personal-task linking, and the related UI flow; its source implementation and local synthetic validation are recorded in `docs/_audit/2026-10-22-android-product-iteration.md`, not a claim of public release or live-account acceptance. Preserve Windows compatibility and keep Apple SwiftUI apps independent; Apple feature work is not the default scope. Read `docs/ANDROID-DEVELOPMENT.md` for product scope, Android interaction rules, safety boundaries, and acceptance; track unfinished work only in `docs/MIRROR-TODO.md`. Development scope is distinct from release status; use the dated implementation and acceptance records for completed evidence.

## Project Structure & Module Organization

Ginkgo (BUAA Assistant) is a native Swift/SwiftUI campus-services client for macOS with an iOS app. Shared application code lives in `BUAA-Assistant/`: `Features/` groups Auth, Today, Schedule, Grade, Graduate, Homework, BYKC, Library, Venue (CGYY), Campus, Classroom, CheckIn, Tasks, and Settings; `Core/` contains shared networking, storage, time/parsing/crypto helpers, logging, the shared workspace coordinator, and cross-platform UI components. The macOS application shell is in `BUAA-Assistant/` root; the iOS shell, XcodeGen spec, resources, and iOS-only settings live in `BUAA-Assistant-iOS/`. Keep feature-specific clients, models, parsers, views, and view models together. XCTest sources live in `BUAA-AssistantTests/` and are shared by both projects. Treat `docs/` as the documentation source of truth; start with `ROADMAP.md`, `ARCHITECTURE.md`, `API.md`, `IOS.md`, and `IMPROVEMENTS.md`.

## Build, Test, and Development Commands

Use Xcode 16+ on macOS (macOS deployment target: 14; iOS target: 17). Open `BUAA-Assistant.xcodeproj` for macOS or `BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj` for iOS. From the repository root:

```sh
xcodebuild build -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet

xcodebuild build -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet
xcodebuild build-for-testing -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet
xcrun simctl list devices available
xcodebuild test -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -quiet

git diff --check
```

The iOS project is generated from `BUAA-Assistant-iOS/project.yml` with XcodeGen 2.46+. Do not hand-edit generated `.xcodeproj` files; update the spec and regenerate with:

```sh
cd BUAA-Assistant-iOS
xcodegen generate --spec project.yml
```

iOS simulator XCTest requires an installed Simulator Runtime. A generic-device build and `build-for-testing` validate compilation but are not a substitute for simulator/device acceptance.

## Coding Style & Naming Conventions

Match existing Swift code: two-space indentation, `UpperCamelCase` types, and `lowerCamelCase` properties and methods. Name files after their primary type, such as `ScheduleViewModel.swift`. Keep UI state on `@MainActor` and isolate parsing from networking and presentation. No formatter or linter configuration is currently checked in. AI contributors must not hand-edit `.xcodeproj`; update `BUAA-Assistant-iOS/project.yml` and regenerate the iOS project with XcodeGen. The macOS project remains Xcode-managed; describe required macOS target changes for a maintainer.

## Testing Guidelines

Use XCTest with `@testable import BUAA_Assistant`. Name files `<Subject>Tests.swift` and methods descriptively, such as `test_loginFields_addsRequiredDefaults`. Cover parser edge cases, session failures, and changed business rules with synthetic data and mocked responses. Add regression tests for fixes. iOS UI smoke tests live in `BUAA-Assistant-iOS/UITests/`; use launch environments for fixtures, never commit live credentials. The optional live-account test reads `GINKGO_LIVE_USERNAME` / `GINKGO_LIVE_PASSWORD` from the simulator process environment only. Network tests must use the `UpstreamRoutePreference` automatic/direct/WebVPN abstractions; do not hardcode `d.buaa.edu.cn` in individual feature clients. Coverage is not yet measured or enforced; `docs/TESTING.md` lists planned targets. Record manual validation separately from automated results.

## User-facing Release Notes

Keep release text (GitHub Release body and in-app update notes) to 3–5 short Chinese bullets, one plain-language user benefit per bullet. Do not include test counts, architecture jargon, build/signing procedures, or dense acceptance reports; link maintainer records instead. Keep a brief explicit warning when data loss, upgrade incompatibility, or safety requires it. Do not pad notes or announce unfinished features; do not rewrite historical releases automatically.

## Commit & Pull Request Guidelines

Recent commits use concise Chinese descriptions with a topic prefix, such as `文档勘误：…`. Explain the change and motivation; use `feat/<module>` or `fix/<issue>` branches and keep `main` usable. PRs should describe scope, validation commands/results, related issues when applicable, and screenshots for UI changes. Update affected documentation; protocol corrections require evidence in `docs/API.md`’s revision table.

## Security & Configuration

Never commit passwords, cookies, tickets, raw HAR files, or personal data. Use Keychain for remembered passwords and redact diagnostic output. Consult `docs/COLLABORATION.md` before changing authentication, TLS, entitlements, or upstream write operations.
