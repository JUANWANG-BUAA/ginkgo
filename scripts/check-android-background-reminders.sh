#!/usr/bin/env bash
# Own a fresh GinkgoBackground* emulator. Never run against an installed account.
set -euo pipefail
cd "$(dirname "$0")/.."
serial="${1:?Pass an isolated emulator serial}"
adb="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
package=cn.edu.buaa.ginkgo.ginkgo_mirror
[[ "$serial" == emulator-* ]] || { echo 'Only isolated emulators are accepted'; exit 1; }
device() { "$adb" -s "$serial" "$@"; }
avd="$(device emu avd name | tr -d '\r' | head -n 1)"
[[ "$avd" == GinkgoBackground* ]] || { echo 'Use a fresh GinkgoBackground* AVD'; exit 1; }
logs="$(mktemp -d "${TMPDIR:-/tmp}/ginkgo-background.XXXXXX")"
test_pid=
stage=engine
cleanup() {
  if [[ -n "$test_pid" ]]; then kill "$test_pid" 2>/dev/null || true; wait "$test_pid" 2>/dev/null || true; fi
  echo "Background QA logs: $logs"
  echo "Last QA stage: $stage"
}
trap cleanup EXIT
device shell cmd connectivity airplane-mode enable
device logcat -c

(cd flutter && flutter test --no-pub integration_test/background_reminders_test.dart -d "$serial" \
  --dart-define=GINKGO_TEST_BACKGROUND_REMINDERS=true) >"$logs/engine.log" 2>&1 &
test_pid=$!
ready=false
for ((i=0; i<180; i++)); do
  if rg -q GINKGO_BACKGROUND_TEST_READY "$logs/engine.log"; then ready=true; break; fi
  kill -0 "$test_pid" 2>/dev/null || break
  sleep 1
done
[[ "$ready" == true ]] || { tail -50 "$logs/engine.log"; exit 1; }
device shell input keyevent KEYCODE_HOME
sleep 3
device shell cmd jobscheduler run -f "$package" 7109
wait "$test_pid"
test_pid=
echo 'PASS: native group/owner isolation and a second Flutter engine'
stage=cold-process

(cd flutter && flutter build apk --debug --target-platform android-arm64 \
  --target integration_test/background_reminders_probe.dart \
  --dart-define=GINKGO_TEST_BACKGROUND_REMINDERS=true --no-pub) >"$logs/probe-build.log" 2>&1
device install -r flutter/build/app/outputs/flutter-apk/app-debug.apk
device shell am start -n "$package/.MainActivity"
ready=false
for ((i=0; i<45; i++)); do
  if device logcat -d -s flutter:I | rg -q GINKGO_COLD_BACKGROUND_READY; then ready=true; break; fi
  sleep 1
done
[[ "$ready" == true ]]
device shell input keyevent KEYCODE_HOME
sleep 3
device shell am kill "$package"
for ((i=0; i<30; i++)); do
  [[ -z "$(device shell pidof "$package" || true)" ]] && break
  sleep 1
done
[[ -z "$(device shell pidof "$package" || true)" ]]

read_run() {
  local expected="${1:-retryLater}"
  device exec-out run-as "$package" cat shared_prefs/reminder-background-v1.xml |
    python3 -c 'import sys,xml.etree.ElementTree as E; r=E.parse(sys.stdin).getroot(); d={n.get("name"): n.get("value",n.text) for n in r}; print(d.get("lastRun","0") if d.get("status")==sys.argv[1] else "0")' "$expected"
}
wait_run() {
  local previous="$1" current=0 expected="${2:-retryLater}"
  for ((j=0; j<45; j++)); do
    current="$(read_run "$expected")"
    if ((current > previous)); then echo "$current"; return; fi
    sleep 1
  done
  return 1
}
device shell cmd jobscheduler run -f "$package" 7109
first="$(wait_run 0)"
echo "PASS: process-death cold JNI/FRB completion ($first)"

# Use Android's normal shutdown path. `adb reboot` can reset the emulator
# before PackageManager flushes a just-installed app's launched state.
stage=reboot
device shell cmd package wait-for-handler --timeout 30000
boot_id="$(device shell cat /proc/sys/kernel/random/boot_id | tr -d '\r')"
# A normal reboot may close the shell transport before returning its exit code.
device shell svc power reboot || true
device wait-for-device
for ((i=0; i<120; i++)); do
  current_boot="$(device shell cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '\r' || true)"
  if [[ -n "$current_boot" && "$current_boot" != "$boot_id" &&
    "$(device shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" == 1 ]]; then break; fi
  sleep 1
done
[[ -n "$current_boot" && "$current_boot" != "$boot_id" ]]
[[ "$(device shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]
device shell input keyevent 82
ready=false
for ((i=0; i<30; i++)); do
  device shell dumpsys alarm >"$logs/reboot-alarms.log"
  if rg -q 'cn.edu.buaa.ginkgo.reminder.aaaaaaaa' "$logs/reboot-alarms.log"; then ready=true; break; fi
  sleep 1
done
[[ "$ready" == true ]]
echo 'PASS: reboot re-arms the unexpired synthetic alarm without an Activity'
stage=normal-entrypoint

# Optional AOT exercise, with no public signing or publication. Debug is always
# rebuilt last so the resulting artifact has the normal lib/main.dart entry.
if [[ "${GINKGO_BACKGROUND_CHECK_PROFILE:-0}" == 1 ]]; then
  (cd flutter && flutter build apk --profile --target-platform android-arm64 \
    --target lib/main.dart --pub) >"$logs/profile-build.log" 2>&1
  device install -r flutter/build/app/outputs/flutter-apk/app-profile.apk
  device logcat -c
  device shell cmd jobscheduler run -f "$package" 7109
  sleep 15
  device logcat -d -s flutter:E AndroidRuntime:E >"$logs/profile-errors.log"
  if rg -q 'Could not resolve|Could not create root isolate|FATAL EXCEPTION' "$logs/profile-errors.log"; then
    echo 'AOT background engine failed'; exit 1
  fi
fi
(cd flutter && flutter build apk --debug --target-platform android-arm64 \
  --target lib/main.dart --pub) >"$logs/main-build.log" 2>&1
device install -r flutter/build/app/outputs/flutter-apk/app-debug.apk
if [[ "${GINKGO_BACKGROUND_CHECK_PROFILE:-0}" == 1 ]]; then
  profile="$(read_run)"
  ((profile > first))
  first="$profile"
  echo "PASS: normal-entrypoint AOT engine completes headlessly ($profile)"
fi
device logcat -c
device shell cmd jobscheduler run -f "$package" 7109
last="$(wait_run "$first")"
device logcat -d -s flutter:E AndroidRuntime:E >"$logs/main-errors.log"
if rg -q 'Could not resolve|Could not create root isolate|FATAL EXCEPTION' "$logs/main-errors.log"; then
  echo 'Normal-entrypoint background engine failed'; exit 1
fi
echo "PASS: normal-entrypoint APK upgrade and cold job completion ($last)"
stage=unreadable-session
device shell am kill "$package"
for ((i=0; i<30; i++)); do
  [[ -z "$(device shell pidof "$package" || true)" ]] && break
  sleep 1
done
[[ -z "$(device shell pidof "$package" || true)" ]]
device push flutter/integration_test/data/invalid-session.xml /data/local/tmp/ginkgo-invalid-session.xml
device shell run-as "$package" cp /data/local/tmp/ginkgo-invalid-session.xml shared_prefs/ginkgo_secure_session.xml
device shell cmd jobscheduler run -f "$package" 7109
broken="$(wait_run "$last" storageUnavailable)"
echo "PASS: native session read error is distinct from a missing account ($broken)"
device shell am start -n "$package/.MainActivity"
ready=false
for ((i=0; i<20; i++)); do
  device shell uiautomator dump /data/local/tmp/ginkgo-recovery.xml >/dev/null
  device exec-out cat /data/local/tmp/ginkgo-recovery.xml >"$logs/recovery-ui.xml"
  if rg -q '暂未恢复登录状态' "$logs/recovery-ui.xml"; then ready=true; break; fi
  sleep 1
done
[[ "$ready" == true ]]
rg -q '重试恢复' "$logs/recovery-ui.xml"
device exec-out run-as "$package" cat shared_prefs/ginkgo_secure_session.xml >"$logs/retained-session.xml"
cmp flutter/integration_test/data/invalid-session.xml "$logs/retained-session.xml"
device exec-out screencap -p >"$logs/recovery.png"
device shell rm /data/local/tmp/ginkgo-invalid-session.xml /data/local/tmp/ginkgo-recovery.xml
echo 'PASS: normal UI offers recovery and retains the unreadable synthetic record'
stage=complete
# The test owns only this disposable emulator; remove all synthetic app data.
device shell pm clear "$package"
echo 'PASS: all background checks finished without an account or school request'
