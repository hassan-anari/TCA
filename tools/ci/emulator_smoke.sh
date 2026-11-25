#!/usr/bin/env bash
# Emulator smoke test for the Memoria Phase 00 prototype.
#   tools/ci/emulator_smoke.sh <release-apk> <out-dir>
#
# 1. Installs + launches the release APK (x86_64 build of the same sources).
# 2. Captures real screenshots of every required screen via prototype deep
#    links, plus a screen recording of the exploration + reveal sequence.
# 3. Runs the frame-timing capture (flutter drive --profile).
# 4. Runs the on-device integration flow test (real renderer).
#
# Emulator = x86_64 + SwiftShader software GPU: visuals are representative,
# performance numbers are NOT physical-device numbers.
set -uo pipefail
APK="$1"
OUT="$2"
PKG="app.memoria.prototype.phase00"
mkdir -p "$OUT/screenshots" "$OUT/logs"
STATUS="$OUT/status.txt"
: > "$STATUS"
fail=0

note() { echo "$*" | tee -a "$STATUS"; }

shot() {
  sleep "${2:-6}"
  adb exec-out screencap -p > "$OUT/screenshots/$1.png" && note "screenshot $1.png ($(stat -c%s "$OUT/screenshots/$1.png") bytes)"
}

link() {
  adb shell am start -W -a android.intent.action.VIEW -d "memoria://prototype$1" "$PKG" > /dev/null 2>&1
}

adb wait-for-device
adb shell getprop ro.build.version.release | sed 's/^/android=/' | tee -a "$STATUS"
adb shell getprop ro.product.cpu.abi | sed 's/^/abi=/' | tee -a "$STATUS"
adb shell wm size | tee -a "$STATUS"
adb logcat -c || true

# ---------------------------------------------------------------- install
if adb install -r "$APK" > "$OUT/logs/install.txt" 2>&1; then
  note "install: OK"
else
  note "install: FAILED"; cat "$OUT/logs/install.txt"; exit 1
fi

# ------------------------------------------------------------------ launch
START=$(date +%s%N)
adb shell am start -W -n "$PKG/app.memoria.prototype.MainActivity" | tee "$OUT/logs/launch.txt"
sleep 3
if adb shell pidof "$PKG" > /dev/null; then note "launch: OK (process alive)"; else note "launch: FAILED"; fail=1; fi

adb shell screenrecord --time-limit 170 --bit-rate 6000000 /sdcard/memoria-flow.mp4 &
REC=$!

shot 01_universe 25
adb shell input swipe 700 1500 380 1350 700
shot 01b_universe_after_drag 3

link "/galaxy/2025";                                   shot 02_galaxy_2025 10
link "/galaxy/2025?focus=m-2025-old-tree";             shot 02b_galaxy_planet_selected 8
link "/galaxy/2026";                                   shot 02c_galaxy_2026_locked_and_shared 10
link "/planet/m-2025-old-tree";                        shot 03_memory_planet_hero 10
adb shell input swipe 300 1200 800 1200 600
shot 03b_memory_planet_rotated 3
link "/create";                                        shot 04_create_capsule 6
link "/capsule/m-2026-letter";                         shot 05_locked_capsule 10
link "/capsule/m-2026-our-capsule?prototypeClock=unlock"; shot 05b_capsule_ready_after_prototype_clock 8
link "/reveal/m-2026-our-capsule"
shot 06a_reveal_anticipation 1.2
shot 06b_reveal_dissolve 1.0
shot 06c_reveal_bloom 1.0
shot 06d_reveal_complete 4
link "/read/m-2025-old-tree";                          shot 07_memory_reading 6
adb shell input keyevent KEYCODE_BACK;                 shot 08_planet_evolved_after_reading 10
link "/";                                              shot 09_universe_return 10

kill -INT $REC 2>/dev/null; sleep 3
adb pull /sdcard/memoria-flow.mp4 "$OUT/memoria-flow.mp4" > /dev/null 2>&1 && note "recording: memoria-flow.mp4" || note "recording: unavailable"

if adb shell pidof "$PKG" > /dev/null; then note "still running after flow: OK"; else note "app process died during flow: FAILED"; fail=1; fi
adb logcat -d > "$OUT/logs/logcat-release.txt" 2>&1 || true
grep -E "Memoria scene init failed|FATAL EXCEPTION|SIGSEGV|Filament" "$OUT/logs/logcat-release.txt" | head -50 > "$OUT/logs/logcat-highlights.txt" || true
adb shell dumpsys meminfo "$PKG" > "$OUT/logs/meminfo.txt" 2>&1 || true
adb shell dumpsys gfxinfo "$PKG" > "$OUT/logs/gfxinfo.txt" 2>&1 || true

# ------------------------------------------------------- frame timings (profile)
adb logcat -c || true
if timeout 1200 flutter drive --profile -d emulator-5554 --driver=test_driver/perf_driver.dart \
     --target=integration_test/perf_test.dart > "$OUT/logs/perf-drive.txt" 2>&1; then
  note "perf drive (profile, emulator): OK"
else
  note "perf drive (profile, emulator): FAILED (see logs/perf-drive.txt)"
fi
cp build/integration_response_data.json "$OUT/perf-emulator-frame-timings.json" 2>/dev/null || true

# ------------------------------------------------------------ integration test
adb logcat -c || true
if timeout 1500 flutter test integration_test/app_flow_test.dart -d emulator-5554 --reporter expanded \
     > "$OUT/logs/integration-test.txt" 2>&1; then
  note "integration test (real renderer, emulator): PASSED"
else
  note "integration test (real renderer, emulator): FAILED (see logs/integration-test.txt)"
  fail=1
fi
adb logcat -d > "$OUT/logs/logcat-integration.txt" 2>&1 || true

cat "$STATUS"
exit $fail
