# Android Beta.1 Release Closeout and Promo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver a verified Android Beta.1 release candidate and a faster, clearer Android-first promotional site without claiming unperformed real-account, write, or physical-device acceptance.

**Architecture:** Keep application changes limited to reproducible release blockers with regression tests. Keep the promotional site dependency-free: semantic HTML, existing CSS custom properties, small vanilla JavaScript enhancements, static working download fallbacks, and generated local image assets.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Rust 1.99, Android SDK 36, HTML/CSS/JavaScript, GitHub Releases API, Playwright browser verification, Python 3 image-generation tooling already available on the host.

---

### Task 1: Establish the release and content baseline

**Files:**
- Read: `docs/MIRROR-TODO.md`
- Read: `docs/_audit/2026-10-27-android-beta1-preparation.md`
- Read: `docs/PROMOTION.md`
- Read: `.github/workflows/android-release.yml`
- Modify only if a reproducible blocker is found: the owning Rust/Dart source and its existing test file

- [x] **Step 1: Run the repository gate before changes**

Run: `bash scripts/check-mirror.sh`
Expected: architecture checks, formatting, Clippy, Rust tests, Flutter analysis/tests, Cargokit analysis and FRB consistency all exit 0.

- [x] **Step 2: Audit release claims against implementation**

Run: `git status --short`, `gh run list --limit 8`, and targeted searches for snapshot persistence, write retry protection, credentials and logging.
Expected: every deleted or rewritten promotional claim maps to current source or a dated acceptance record; unresolved real-account, write and physical-device gaps remain explicit.

- [x] **Step 3: Fix only evidenced blockers using regression-first changes**

For each reproduced blocker, add a failing case to the existing owning test suite, run it to observe the original failure, make the smallest source change, and rerun that case plus its module suite. Do not broaden scope when no defect is reproduced.

### Task 2: Rebuild the Android-first page structure and release presentation

**Files:**
- Modify: `docs/index.html`
- Modify: `docs/landing.css`
- Modify: `docs/landing.js`

- [x] **Step 1: Replace the competing platform narrative with a Beta journey**

Organize the page into hero, high-frequency scenarios, concise product gallery, three-step Android installation, Beta limitations, privacy/feedback, and a compact secondary-platform footer. Use one primary APK CTA per viewport section, visible Android 7.0+ / ARM64 requirements, non-official-project disclosure, and a direct issue link.

- [x] **Step 2: Add dynamic Beta status without breaking static fallback**

Keep the static Alpha.9 URLs until Beta.1 is published. In `landing.js`, derive the Android channel from the selected release tag and update only Android-specific labels:

```js
const channel = android.tag_name.includes("-beta.")
  ? "Beta"
  : android.tag_name.includes("-alpha.") ? "Alpha" : "Release";
updateText("[data-android-channel]", channel);
```

Do not select drafts; do not let Mac or Windows releases replace Android links. Preserve the existing eight-second timeout and trusted-GitHub URL validation.

- [x] **Step 3: Implement responsive and accessible styling**

Use the existing forest tokens, 48px primary touch targets, visible `:focus-visible`, mobile navigation, native `details` FAQ, native `dialog` preview and `prefers-reduced-motion`. At 320px, keep download controls and compatibility text wrapping without horizontal page overflow.

- [x] **Step 4: Verify structure in a browser**

Serve `docs/` over a local HTTP server and inspect desktop and 320/390px mobile layouts. Assert the hero, installation, Beta limitations, privacy and feedback links are visible; open/close mobile navigation and the screenshot dialog; confirm Escape returns focus to the originating screenshot.

### Task 3: Optimize promotional media and social sharing

**Files:**
- Create: `docs/images/ginkgo-android-social.png`
- Create: `docs/images/android-*-640.webp`
- Modify: `docs/index.html`
- Modify: `docs/PROMOTION.md`

- [x] **Step 1: Generate correctly sized local assets**

Use Pillow if already installed; otherwise use available macOS `sips` for resizing and retain PNG fallbacks. Resize page-display images to 640px wide, generate WebP only with a supported tool, and compose a 1200×630 social card from the existing mark, Android screenshot and truthful product copy. Read generated images back for clipping, legibility and synthetic-data compliance.

- [x] **Step 2: Wire responsive images and social metadata**

Use `<picture>` with WebP source and original PNG fallback, explicit dimensions, high priority only for the hero image, and lazy loading below the fold. Point `og:image` and `twitter:card` to the absolute 1200×630 social asset.

- [x] **Step 3: Verify media behavior**

Check every referenced asset returns HTTP 200, no video autoplays, preview uses the selected full image, and narrow screens do not download desktop-only styling resources. Compare asset dimensions and total transfer against the original full-PNG page.

### Task 4: Correct public copy and add Beta feedback paths

**Files:**
- Modify: `README.md`
- Modify: `docs/PROMOTION.md`
- Modify: `docs/RELEASE-NOTES.md`
- Modify: `docs/releases/android-beta1.md`
- Modify: `docs/_audit/2026-10-27-android-beta1-preparation.md`
- Modify: `docs/MIRROR-TODO.md`
- Create: `.github/ISSUE_TEMPLATE/android-beta.md`
- Create: `.github/ISSUE_TEMPLATE/config.yml`

- [x] **Step 1: Rewrite absolute or stale claims**

Replace “数据不上传” with the precise direct-school/WebVPN and no-project-relay statement. Remove any implication of complete post-restart offline snapshots. Keep unverified loans, lock codes, school writes and realtime shuttle availability visibly qualified.

- [x] **Step 2: Add a structured Android Beta issue form**

Use a Markdown issue template requesting Ginkgo version, Android version/device, account type, network route, reproduction steps, expected/actual behavior and sanitized screenshots. Include this warning verbatim:

```markdown
**不要提交密码、Cookie、token、真实学号、课表/成绩原文、HAR 或未打码截图。**
```

Disable blank issues through `config.yml` and link the GitHub Discussions page only if it exists; otherwise link the repository readme and keep issue creation available.

- [x] **Step 3: Keep release notes user-centered**

Retain 3–5 concise benefits, move technical validation into the dated preparation record, and state physical-device/real-write limitations separately. Do not mark Beta.1 published before a real prerelease exists.

### Task 5: Verify the complete promotional site

**Files:**
- Test: `docs/index.html`
- Test: `docs/landing.js`
- Test: `docs/landing.css`

- [x] **Step 1: Exercise functional paths**

With JavaScript enabled and disabled, follow primary APK, checksum, release, issue, privacy and repository links. Force the GitHub releases request to fail and confirm the static Alpha.9 download remains unchanged. Mock a Beta.1 API response and confirm Android labels and all Android URLs update together.

- [x] **Step 2: Exercise viewport and accessibility paths**

Check 320, 390, 768 and 1440px widths for overflow and clipped CTAs. Navigate the menu, FAQ and dialog by keyboard; verify visible focus, Escape behavior, meaningful image alt text and reduced-motion CSS.

- [x] **Step 3: Inspect final screenshots and console**

Capture full-page desktop and mobile screenshots, inspect them visually, and require zero page JavaScript errors and zero missing local assets. Do not claim Lighthouse scores unless Lighthouse was actually run.

### Task 6: Build and verify the Beta.1 candidate, then close documentation

**Files:**
- Modify: `docs/_audit/2026-10-27-android-beta1-preparation.md`
- Modify: `docs/MIRROR-IMPLEMENTATION.md`
- Modify: `docs/MIRROR-TODO.md`

- [x] **Step 1: Run final source gates**

Run: `bash scripts/check-mirror.sh && git diff --check`
Expected: exit 0 with no analyzer warnings, test failures, generated-binding drift or whitespace errors.

- [x] **Step 2: Build the signed production APK**

Run from `flutter/`: `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`
Expected: `build/app/outputs/flutter-apk/app-release.apk` built with the maintainer’s external signing configuration. If unavailable, record the exact external blocker and never substitute a Debug package.

- [x] **Step 3: Verify package identity and integrity**

Use Android SDK `aapt`, `apksigner` and `zipalign`, plus `sha256sum`/`shasum -a 256`. Require version `0.1.0-beta.1`, versionCode `11`, package `cn.edu.buaa.ginkgo.ginkgo_mirror`, only `arm64-v8a`, no debuggable marker, no integration-test driver, valid alignment/signature, and the same signing certificate as Alpha.9.

- [x] **Step 4: Verify Alpha.9 to Beta.1 upgrade on an Android emulator**

Install the official Alpha.9 signed APK, create a synthetic local-task sentinel, install Beta.1 with `adb install -r`, and confirm versionCode 11, unchanged firstInstallTime and the retained sentinel. Do not use a real account or school write operation.

- [x] **Step 5: Record evidence and remaining external gates**

Update the dated preparation record with commands, environment, package digest, certificate comparison and upgrade outcome. Leave physical Android TalkBack, large-text, predictive-back and real-school acceptance unchecked if not actually performed. Do not tag, push, or publish a Release.
