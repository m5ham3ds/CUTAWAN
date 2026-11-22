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
install -m 0644 "$SCRIPT_DIR/android/NativeRenderEngine.kt" "$MAIN_ACTIVITY_DIR/NativeRenderEngine.kt"
install -m 0644 "$SCRIPT_DIR/android/NativeRenderWorker.kt" "$MAIN_ACTIVITY_DIR/NativeRenderWorker.kt"

# Direct HTTP/HTTPS media import needs INTERNET in the release manifest, too.
MAIN_MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST"; then
  sed -i '/<manifest /a\    <uses-permission android:name="android.permission.INTERNET" />' "$MAIN_MANIFEST"
fi
grep -q 'android.permission.INTERNET' "$MAIN_MANIFEST"

# Keep Keystore-backed credentials from being restored onto a device that
# does not possess the original Android Keystore key material.
python3 - <<'PY'
from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
source = manifest.read_text()
match = re.search(r"<application\b[^>]*>", source, flags=re.S)
if not match:
    raise SystemExit("Could not locate the Android application manifest element.")
tag = match.group(0)
if re.search(r'android:allowBackup\s*=', tag):
    tag = re.sub(
        r'android:allowBackup\s*=\s*"[^"]*"',
        'android:allowBackup="false"',
        tag,
    )
else:
    tag = tag[:-1] + ' android:allowBackup="false">'
source = source[:match.start()] + tag + source[match.end():]
# WorkManager's long-running worker owns Media3 rendering and declares
# the required foreground-service capabilities in the merged application manifest.
root_match = re.search(r"<manifest\b[^>]*>", source, flags=re.S)
if not root_match:
    raise SystemExit("Could not locate the Android manifest root element.")
root_tag = root_match.group(0)
if "xmlns:tools=" not in root_tag:
    root_tag = root_tag[:-1] + ' xmlns:tools="http://schemas.android.com/tools">'
    source = source[:root_match.start()] + root_tag + source[root_match.end():]

permissions = [
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PROCESSING",
    "android.permission.POST_NOTIFICATIONS",
]
for permission in permissions:
    if permission not in source:
        root_match = re.search(r"<manifest\b[^>]*>", source, flags=re.S)
        source = source[:root_match.end()] + f'\n    <uses-permission android:name="{permission}" />' + source[root_match.end():]

service = (
    '<service android:name="androidx.work.impl.foreground.SystemForegroundService" '
    'android:foregroundServiceType="dataSync|mediaProcessing" '
    'tools:node="merge" tools:replace="android:foregroundServiceType" />'
)
service_match = re.search(
    r'<service\b[^>]*android:name="androidx\.work\.impl\.foreground\.SystemForegroundService"[^>]*/?>',
    source,
    flags=re.S,
)
if service_match:
    source = source[:service_match.start()] + service + source[service_match.end():]
else:
    application_end = source.find("</application>")
    if application_end < 0:
        raise SystemExit("Could not locate the Android application closing element.")
    source = source[:application_end] + "        " + service + "\n    " + source[application_end:]

manifest.write_text(source)
verified = manifest.read_text()
if 'android:allowBackup="false"' not in verified:
    raise SystemExit("Android backup restriction was not applied.")
for permission in permissions:
    if permission not in verified:
        raise SystemExit(f"Missing foreground/notification permission: {permission}")
if "androidx.work.impl.foreground.SystemForegroundService" not in verified:
    raise SystemExit("WorkManager foreground service declaration was not added.")
print("Verified Android backup restriction and WorkManager foreground-service manifest.")

PY

# The mobile artifact is intentionally ARM64-only.
python3 - <<'PY'
from pathlib import Path
import re

kts = Path("android/app/build.gradle.kts")
groovy = Path("android/app/build.gradle")
if kts.is_file():
    path = kts
    block = '        ndk {\n            abiFilters.clear()\n            abiFilters.addAll(listOf("arm64-v8a"))\n        }'
elif groovy.is_file():
    path = groovy
    block = "        ndk { abiFilters.clear(); abiFilters.addAll(['arm64-v8a']) }"
else:
    raise SystemExit("Flutter Android app Gradle file was not generated.")

source = path.read_text()
if not re.search(r'(?s)abiFilters.{0,200}arm64-v8a', source):
    match = re.search(r'(?m)^(\s*)defaultConfig\s*\{\s*$', source)
    if not match:
        raise SystemExit(f"Could not find defaultConfig block in {path}")
    insertion = match.group(0) + "\n" + block
    source = source[:match.start()] + insertion + source[match.end():]
    path.write_text(source)

if not re.search(r'(?s)abiFilters.{0,200}arm64-v8a', path.read_text()):
    raise SystemExit(f"ARM64 ABI filter was not applied in {path}")
print(f"Verified ARM64 ABI filter in {path}")
PY

# The selected local llama.cpp plugin requires Android API 26+ and NDK 28.2.
# Keep the app and native dependency minimums aligned.
python3 - <<'PY'
from pathlib import Path
import re

kts = Path("android/app/build.gradle.kts")
groovy = Path("android/app/build.gradle")
if kts.is_file():
    path = kts
    source = path.read_text()
    source, count = re.subn(
        r'(?m)^([ \t]*)minSdk[ \t]*=[ \t]*(?:flutter\.minSdkVersion|\d+)[ \t]*',
        r'\1minSdk = 26',
        source,
        count=1,
    )
    if not count:
        raise SystemExit(f"Could not locate minSdk in {path}")
    source, ndk_count = re.subn(
        r'(?m)^([ \t]*)ndkVersion[ \t]*=.*',
        r'\1ndkVersion = "28.2.13676358"',
        source,
        count=1,
    )
    if not ndk_count:
        source = re.sub(
            r'(?m)^([ \t]*)compileSdk[ \t]*=.*',
            r'\g<0>\n\g<1>ndkVersion = "28.2.13676358"',
            source,
            count=1,
        )
    path.write_text(source)
elif groovy.is_file():
    path = groovy
    source = path.read_text()
    source, count = re.subn(
        r'(?m)^([ \t]*)minSdkVersion[ \t]+(?:flutter\.minSdkVersion|\d+)[ \t]*',
        r'\1minSdkVersion 26',
        source,
        count=1,
    )
    if not count:
        raise SystemExit(f"Could not locate minSdkVersion in {path}")
    source, ndk_count = re.subn(
        r'(?m)^([ \t]*)ndkVersion[ \t]*.*',
        r'\1ndkVersion "28.2.13676358"',
        source,
        count=1,
    )
    if not ndk_count:
        source = re.sub(
            r'(?m)^([ \t]*)compileSdkVersion.*',
            r'\g<0>\n\g<1>ndkVersion "28.2.13676358"',
            source,
            count=1,
        )
    path.write_text(source)
else:
    raise SystemExit("Flutter Android app Gradle file was not generated.")

verify = path.read_text()
if path.suffix == ".kts":
    match = re.search(r'(?m)^[ \t]*minSdk[ \t]*=[ \t]*(\d+)', verify)
else:
    match = re.search(r'(?m)^[ \t]*minSdkVersion[ \t]+(\d+)', verify)
if not match or int(match.group(1)) < 26:
    raise SystemExit(f"Android minSdk must be 26 or newer in {path}")
if "28.2.13676358" not in verify:
    raise SystemExit(f"Android NDK 28.2.13676358 was not selected in {path}")
print(f"Verified minSdk 26+ and NDK 28.2.13676358 in {path}")
PY

flutter pub get

# Media3 Transformer powers native clip trimming and aspect-fit export.
python3 - <<'PY'
from pathlib import Path

kts = Path('android/app/build.gradle.kts')
groovy = Path('android/app/build.gradle')
if kts.is_file():
    path = kts
    dependencies = [
        '    implementation("androidx.media3:media3-transformer:1.11.1")',
        '    implementation("androidx.media3:media3-effect:1.11.1")',
        '    implementation("androidx.media3:media3-common:1.11.1")',
        '    implementation("androidx.work:work-runtime:2.12.0")',
    ]
elif groovy.is_file():
    path = groovy
    dependencies = [
        '    implementation "androidx.media3:media3-transformer:1.11.1"',
        '    implementation "androidx.media3:media3-effect:1.11.1"',
        '    implementation "androidx.media3:media3-common:1.11.1"',
        '    implementation "androidx.work:work-runtime:2.12.0"',
    ]
else:
    raise SystemExit('Flutter did not generate an Android Gradle file.')

source = path.read_text()
lines = source.splitlines()
block_index = next((i for i, line in enumerate(lines) if line.strip() == 'dependencies {'), None)
if block_index is None:
    lines.extend(['', 'dependencies {', *dependencies, '}'])
else:
    for dependency in reversed(dependencies):
        if 'androidx.media3:' in dependency:
            coordinate = dependency.split('androidx.media3:')[1].split(':')[0]
            expected = 'androidx.media3:' + coordinate + ':1.11.1'
        else:
            expected = 'androidx.work:work-runtime:2.12.0'
        if expected not in source:
            lines.insert(block_index + 1, dependency)
source = '\n'.join(lines) + '\n'
for artifact in ('transformer', 'effect', 'common'):
    expected = 'androidx.media3:media3-' + artifact + ':1.11.1'
    if expected not in source:
        raise SystemExit('Missing Media3 dependency: ' + expected)
if 'androidx.work:work-runtime:2.12.0' not in source:
    raise SystemExit('Missing WorkManager 2.12.0 dependency.')
path.write_text(source)
print('Verified Media3 and WorkManager 2.12.0 dependencies.')
PY
# whisper.cpp defaults BUILD_SHARED_LIBS=ON on Android. llama.cpp exports
# the same libggml-*.so names, so compile Whisper's private GGML as static
# archives. Apply only to the pinned package and fail closed if source drifts.
python3 - <<'PY'
from pathlib import Path

candidates = sorted(
    Path.home().glob(
        '.pub-cache/hosted/pub.dev/whisper_cpp_flutter_plus-0.5.1/'
        'ios/whisper_cpp_flutter_plus/Sources/WhisperCppCore/CMakeLists.txt'
    )
)
if len(candidates) != 1:
    raise SystemExit(
        'Expected exactly one pinned whisper_cpp_flutter_plus 0.5.1 '
        f'WhisperCppCore CMakeLists.txt, found {len(candidates)}'
    )
path = candidates[0]
source = path.read_text()
anchor = 'option(BUILD_SHARED_LIBS "build shared libraries" ${BUILD_SHARED_LIBS_DEFAULT})'
patch = '''if (ANDROID)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build Whisper GGML statically to avoid llama.cpp .so collisions" FORCE)
else()
    option(BUILD_SHARED_LIBS "build shared libraries" ${BUILD_SHARED_LIBS_DEFAULT})
endif()'''
if patch not in source:
    if source.count(anchor) != 1:
        raise SystemExit('Whisper CMake source changed; refusing an unverified GGML patch.')
    source = source.replace(anchor, patch)
    path.write_text(source)
if patch not in path.read_text():
    raise SystemExit('Whisper Android static-GGML patch did not persist.')
print('Verified Android static GGML patch in', path)
PY

# Ensure both JNI plugins were resolved before Gradle starts.
python3 - <<'PY'
import json
from pathlib import Path

metadata = Path('.flutter-plugins-dependencies')
if not metadata.is_file():
    raise SystemExit('Flutter did not create .flutter-plugins-dependencies')
data = json.loads(metadata.read_text())
plugins = {item.get('name') for item in data.get('plugins', {}).get('android', [])}
required = {'whisper_cpp_flutter_plus', 'llama_flutter_android'}
missing = sorted(required - plugins)
if missing:
    raise SystemExit(f'Missing required Android plugins: {missing}')
print('Verified native plugins:', ', '.join(sorted(required)))
PY
