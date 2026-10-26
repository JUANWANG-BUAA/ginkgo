#!/usr/bin/env bash
# Only an isolated QA emulator: changes its viewport temporarily, never logs in.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-emulator-5580}"
output="${2:-$PWD/artifacts/local/module-visual}"
case "$device" in emulator-*) ;; *) echo "Use an isolated QA emulator, not a personal device." >&2; exit 1 ;; esac
adb="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}/platform-tools/adb"
"$adb" -s "$device" get-state >/dev/null
python3 scripts/capture-android-module-visual.py "$output" &
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
flutter test integration_test/learning_snapshots_test.dart -d "$device"
flutter test integration_test/module_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true -d "$device"
"$adb" -s "$device" shell wm size 960x2100
"$adb" -s "$device" shell wm density 480
flutter test integration_test/module_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true --dart-define=GINKGO_VISUAL_LARGE=true -d "$device"
# Stress status text at 3.2x independently of school modules; capture the scroll end too.
flutter test integration_test/module_visual_test.dart --dart-define=GINKGO_VISUAL_CAPTURE=true --dart-define=GINKGO_VISUAL_PRIMITIVES_ONLY=true --dart-define=GINKGO_VISUAL_SCALE_PERCENT=320 -d "$device"
# Tests overwrite app-debug.apk. Restore a normal-entry artifact for installation.
flutter build apk --debug --target-platform android-arm64 --target lib/main.dart
