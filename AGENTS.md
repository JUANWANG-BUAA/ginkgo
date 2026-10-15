# Repository Guidelines

## Project Structure & Module Organization

BUAA Assistant is a native Swift/SwiftUI macOS campus-services client. Application code lives in `BUAA-Assistant/`: `Features/` groups Auth, Schedule, Grade, Library, Classroom, Today, Tasks, and Settings; `Core/` contains shared networking, storage, logging, and UI components. Keep feature-specific clients, models, parsers, views, and view models together. XCTest sources live in `BUAA-AssistantTests/`. Treat `docs/` as the documentation source of truth; start with `ROADMAP.md`, `ARCHITECTURE.md`, and `API.md`.

## Build, Test, and Development Commands

Use Xcode 16+ on macOS (deployment target: macOS 14). Open `BUAA-Assistant.xcodeproj`, select the `BUAA-Assistant` scheme, and use Command-R to run or Command-U to test. From the repository root:

```sh
xcodebuild build -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
git diff --check
```

These commands build without signing, execute the test suite, and check whitespace errors, respectively.

## Coding Style & Naming Conventions

Match existing Swift code: two-space indentation, `UpperCamelCase` types, and `lowerCamelCase` properties and methods. Name files after their primary type, such as `ScheduleViewModel.swift`. Keep UI state on `@MainActor` and isolate parsing from networking and presentation. No formatter or linter configuration is currently checked in. AI contributors must not hand-edit `.xcodeproj`; describe required configuration changes for a maintainer to apply in Xcode.

## Testing Guidelines

Use XCTest with `@testable import BUAA_Assistant`. Name files `<Subject>Tests.swift` and methods descriptively, such as `test_loginFields_addsRequiredDefaults`. Cover parser edge cases, session failures, and changed business rules with synthetic data and mocked responses. Add regression tests for fixes. Coverage is not yet measured or enforced; `docs/TESTING.md` lists planned targets. Record manual validation separately from automated results.

## Commit & Pull Request Guidelines

Recent commits use concise Chinese descriptions with a topic prefix, such as `文档勘误：…`. Explain the change and motivation; use `feat/<module>` or `fix/<issue>` branches and keep `main` usable. PRs should describe scope, validation commands/results, related issues when applicable, and screenshots for UI changes. Update affected documentation; protocol corrections require evidence in `docs/API.md`’s revision table.

## Security & Configuration

Never commit passwords, cookies, tickets, raw HAR files, or personal data. Use Keychain for remembered passwords and redact diagnostic output. Consult `docs/COLLABORATION.md` before changing authentication, TLS, entitlements, or upstream write operations.
