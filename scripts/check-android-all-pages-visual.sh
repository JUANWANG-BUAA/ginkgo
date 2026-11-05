#!/usr/bin/env bash
# Capture workspace destinations and synthetic detail pages with synthetic
# data, in light and dark appearance at standard and narrow/large-text layouts.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"
output="${2:-$PWD/artifacts/local/ui-review/all-pages}"
case "$device" in emulator-*) ;; *) echo "Use an isolated QA emulator, not a personal device." >&2; exit 1 ;; esac
sdk="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
adb="$sdk/platform-tools/adb"
"$adb" -s "$device" get-state >/dev/null
mkdir -p "$output"
python3 scripts/capture-android-module-visual.py "$output" --device "$device" --adb "$adb" &
receiver=$!
cleanup() {
  kill "$receiver" 2>/dev/null || true
  "$adb" -s "$device" reverse --remove tcp:18765 >/dev/null 2>&1 || true
  "$adb" -s "$device" shell wm size reset >/dev/null 2>&1 || true
  "$adb" -s "$device" shell wm density reset >/dev/null 2>&1 || true
}
trap cleanup EXIT
"$adb" -s "$device" reverse tcp:18765 tcp:18765
cd flutter
if [[ -n "${GINKGO_VISUAL_ONLY:-}" ]]; then
  flutter test integration_test/all_pages_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true --dart-define="GINKGO_VISUAL_ONLY=${GINKGO_VISUAL_ONLY}" -d "$device"
  "$adb" -s "$device" shell wm size 960x2100
  "$adb" -s "$device" shell wm density 480
  flutter test integration_test/all_pages_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true --dart-define=GINKGO_VISUAL_LARGE=true --dart-define="GINKGO_VISUAL_ONLY=${GINKGO_VISUAL_ONLY}" -d "$device"
  "$adb" -s "$device" shell wm size reset
  "$adb" -s "$device" shell wm density reset
  flutter build apk --debug --target-platform android-arm64 --target lib/main.dart
  exit 0
fi
flutter test integration_test/all_pages_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true -d "$device"
"$adb" -s "$device" shell wm size 960x2100
"$adb" -s "$device" shell wm density 480
flutter test integration_test/all_pages_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true --dart-define=GINKGO_VISUAL_LARGE=true -d "$device"
"$adb" -s "$device" shell wm size reset
"$adb" -s "$device" shell wm density reset
flutter build apk --debug --target-platform android-arm64 --target lib/main.dart
