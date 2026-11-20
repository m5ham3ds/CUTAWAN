#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f pubspec.yaml ]]; then
  echo "pubspec.yaml not found; run this script from the mobile Flutter project."
  exit 1
fi

# Let the installed Flutter SDK own its Gradle/Kotlin project template.
flutter create --platforms=android --org com.m5ham3ds --project-name cutawan_mobile .

MAIN_ACTIVITY_DIR="android/app/src/main/kotlin/com/m5ham3ds/cutawan_mobile"
mkdir -p "$MAIN_ACTIVITY_DIR"
install -m 0644 "$SCRIPT_DIR/android/MainActivity.kt" "$MAIN_ACTIVITY_DIR/MainActivity.kt"

# Direct HTTP/HTTPS media import needs INTERNET in the release manifest, too.
MAIN_MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST"; then
  sed -i '/<manifest /a\    <uses-permission android:name="android.permission.INTERNET" />' "$MAIN_MANIFEST"
fi
grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST"

# The mobile artifact is intentionally ARM64-only.
APP_GRADLE_KTS="android/app/build.gradle.kts"
APP_GRADLE_GROOVY="android/app/build.gradle"
if [[ -f "$APP_GRADLE_KTS" ]]; then
  if ! grep -q 'abiFilters.*arm64-v8a' "$APP_GRADLE_KTS"; then
    sed -i '/defaultConfig {/a\\        ndk {\\n            abiFilters += setOf("arm64-v8a")\\n        }' "$APP_GRADLE_KTS"
  fi
  grep -q 'abiFilters.*arm64-v8a' "$APP_GRADLE_KTS"
elif [[ -f "$APP_GRADLE_GROOVY" ]]; then
  if ! grep -q 'abiFilters.*arm64-v8a' "$APP_GRADLE_GROOVY"; then
    sed -i "/defaultConfig {/a\\        ndk { abiFilters 'arm64-v8a' }" "$APP_GRADLE_GROOVY"
  fi
  grep -q 'abiFilters.*arm64-v8a' "$APP_GRADLE_GROOVY"
else
  echo "Flutter Android app Gradle file was not generated."
  exit 1
fi

flutter pub get
