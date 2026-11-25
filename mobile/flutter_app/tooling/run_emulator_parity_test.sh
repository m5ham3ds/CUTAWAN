#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_DIR/android"
ARM64_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

cd "$ANDROID_DIR"
./gradlew --no-daemon --stacktrace app:connectedDebugAndroidTest

if [[ ! -s "$ARM64_APK" ]]; then
  echo "Expected the ARM64 debug APK before emulator validation: $ARM64_APK" >&2
  exit 1
fi

ARM64_APK_BACKUP="$(mktemp)"
cp "$ARM64_APK" "$ARM64_APK_BACKUP"
restore_arm64_apk() {
  cp "$ARM64_APK_BACKUP" "$ARM64_APK"
  rm -f "$ARM64_APK_BACKUP"
}
trap restore_arm64_apk EXIT

python3 - <<'PY'
from pathlib import Path

kts = Path("app/build.gradle.kts")
groovy = Path("app/build.gradle")
if kts.is_file():
    path = kts
    old_filter = 'abiFilters.addAll(listOf("arm64-v8a"))'
    new_filter = 'abiFilters.addAll(listOf("x86_64"))'
elif groovy.is_file():
    path = groovy
    old_filter = "abiFilters.addAll(['arm64-v8a'])"
    new_filter = "abiFilters.addAll(['x86_64'])"
else:
    raise SystemExit("Generated Android app Gradle file is missing.")

source = path.read_text()
if source.count(old_filter) != 1:
    raise SystemExit(
        f"Expected one ARM64-only ABI filter in {path}; refusing an unverified test build."
    )
path.write_text(source.replace(old_filter, new_filter, 1))
if new_filter not in path.read_text():
    raise SystemExit("Could not configure the x86_64 emulator test ABI.")
print(f"Configured x86_64-only integration APK in {path}")
PY

EMULATOR_ABI="$(adb -s emulator-5554 shell getprop ro.product.cpu.abi | tr -d '\r')"
echo "Android emulator ABI: $EMULATOR_ABI"
if [[ "$EMULATOR_ABI" != "x86_64" ]]; then
  echo "Expected x86_64 emulator, got: $EMULATOR_ABI" >&2
  exit 1
fi

cd "$PROJECT_DIR"
if timeout 20m flutter test integration_test/clip_preview_export_parity_test.dart -d emulator-5554 --reporter expanded; then
  echo "Flutter preview/export pixel parity integration test command completed."
else
  test_status=$?
  echo "Flutter integration test failed; collecting emulator startup diagnostics."
  adb -s emulator-5554 logcat -d -v threadtime | grep -E -i "AndroidRuntime|FATAL EXCEPTION|UnsatisfiedLinkError|dlopen failed|libflutter|ActivityTaskManager|fatal signal|process.*died" | tail -n 220 || true
  adb -s emulator-5554 shell dumpsys activity activities | tail -n 100 || true
  exit "$test_status"
fi

if timeout 20m flutter test integration_test/clip_preview_export_parity_matrix_test.dart -d emulator-5554 --reporter expanded; then
  echo "Flutter preview/export parity matrix integration test command completed."
else
  test_status=$?
  echo "Flutter preview/export parity matrix failed; collecting emulator diagnostics."
  adb -s emulator-5554 logcat -d -v threadtime | grep -E -i "AndroidRuntime|FATAL EXCEPTION|UnsatisfiedLinkError|dlopen failed|libflutter|ActivityTaskManager|fatal signal|process.*died" | tail -n 220 || true
  adb -s emulator-5554 shell dumpsys activity activities | tail -n 100 || true
  exit "$test_status"
fi
