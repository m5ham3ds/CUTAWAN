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

# Remove the generated still-logo flash from Android's native launch screen.
# The Flutter first frame is deferred until the intro video is initialized.
python3 - <<'PY'
from pathlib import Path
import re
import shutil

res = Path("android/app/src/main/res")
logo = Path("assets/cutawan_logo.jpg")
if not logo.is_file():
    raise SystemExit("The uploaded CUTAWAN logo asset is missing.")

# Use the exact uploaded logo as the Android launcher icon on API 26+.
launcher_logo_dir = res / "drawable-nodpi"
launcher_logo_dir.mkdir(parents=True, exist_ok=True)
shutil.copyfile(logo, launcher_logo_dir / "cutawan_logo.jpg")

values = res / "values"
values.mkdir(parents=True, exist_ok=True)
line = chr(10)
(values / "cutawan_icon_colors.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>' + line
    + '<resources>' + line
    + '    <color name="cutawan_icon_background">#101113</color>' + line
    + '</resources>' + line
)

# The launcher icon changes to the supplied CUTAWAN logo, not Flutter's
# generated placeholder icon.
adaptive_dir = res / "mipmap-anydpi-v26"
adaptive_dir.mkdir(parents=True, exist_ok=True)
adaptive_icon = (
    '<?xml version="1.0" encoding="utf-8"?>' + line
    + '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">' + line
    + '    <background android:drawable="@color/cutawan_icon_background" />' + line
    + '    <foreground android:drawable="@drawable/cutawan_logo" />' + line
    + '</adaptive-icon>' + line
)
for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    (adaptive_dir / name).write_text(adaptive_icon)

# Before Android 12, the native launch screen is only a solid dark canvas.
blank_background = (
    '<?xml version="1.0" encoding="utf-8"?>' + line
    + '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">' + line
    + '    <item><color android:color="#101113" /></item>' + line
    + '</layer-list>' + line
)
launch_files = list(res.glob("drawable*/launch_background.xml"))
if not launch_files:
    launch_files = [res / "drawable" / "launch_background.xml"]
for launch_file in launch_files:
    launch_file.parent.mkdir(parents=True, exist_ok=True)
    launch_file.write_text(blank_background)

# Android 12+ requires a splash drawable. Its transparent vector intentionally
# draws no logo: the first visible branded content is the prepared video frame.
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "drawable" / "cutawan_splash_transparent.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>' + line
    + '<vector xmlns:android="http://schemas.android.com/apk/res/android"' + line
    + '    android:width="288dp"' + line
    + '    android:height="288dp"' + line
    + '    android:viewportWidth="288"' + line
    + '    android:viewportHeight="288"' + line
    + '    android:alpha="0">' + line
    + '    <path android:fillColor="#FFFFFFFF" android:pathData="M0,0h288v288h-288z" />' + line
    + '</vector>' + line
)

def find_style(source: str, name: str):
    return re.search(
        r'(<style[ ]+name="' + re.escape(name) + r'"[^>]*>)(.*?)(</style>)',
        source,
        flags=re.S,
    )

def upsert_item(body: str, name: str, value: str) -> str:
    pattern = r'<item[ ]+name="' + re.escape(name) + r'">.*?</item>'
    replacement = '<item name="' + name + '">' + value + '</item>'
    if re.search(pattern, body, flags=re.S):
        return re.sub(pattern, replacement, body, count=1, flags=re.S)
    return '        ' + replacement + line + body

def patch_theme(source: str, android_12: bool) -> str:
    launch = find_style(source, "LaunchTheme")
    if not launch:
        raise SystemExit("Could not find LaunchTheme in generated Android styles.xml.")
    body = launch.group(2)
    body = upsert_item(body, "android:windowBackground", "@drawable/launch_background")
    if android_12:
        body = upsert_item(body, "android:windowSplashScreenBackground", "#101113")
        body = upsert_item(
            body,
            "android:windowSplashScreenAnimatedIcon",
            "@drawable/cutawan_splash_transparent",
        )
    source = source[:launch.start()] + launch.group(1) + body + launch.group(3) + source[launch.end():]

    normal = find_style(source, "NormalTheme")
    if normal:
        body = upsert_item(normal.group(2), "android:windowBackground", "@drawable/launch_background")
        source = source[:normal.start()] + normal.group(1) + body + normal.group(3) + source[normal.end():]
    return source

base_day = res / "values" / "styles.xml"
if not base_day.is_file():
    raise SystemExit("Generated Android values/styles.xml is missing.")
base_night = res / "values-night" / "styles.xml"
day_source = patch_theme(base_day.read_text(), android_12=False)
night_source = patch_theme(
    base_night.read_text() if base_night.is_file() else base_day.read_text(),
    android_12=False,
)
day_v31 = patch_theme(base_day.read_text(), android_12=True)
night_v31 = patch_theme(
    base_night.read_text() if base_night.is_file() else base_day.read_text(),
    android_12=True,
)

for folder, source in (
    ("values", day_source),
    ("values-night", night_source),
    ("values-v31", day_v31),
    ("values-night-v31", night_v31),
):
    destination = res / folder / "styles.xml"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(source)

# Fail closed if generated Android resources still expose the old splash
# artwork, or if the app launcher does not point at the uploaded logo.
for folder in ("values-v31", "values-night-v31"):
    source = (res / folder / "styles.xml").read_text()
    if "@drawable/cutawan_splash_transparent" not in source:
        raise SystemExit(f"{folder}/styles.xml does not use the blank splash icon.")
    if "android:windowSplashScreenBackground" not in source:
        raise SystemExit(f"{folder}/styles.xml is missing the Android 12 splash background.")

for icon_name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    icon_file = adaptive_dir / icon_name
    if "@drawable/cutawan_logo" not in icon_file.read_text():
        raise SystemExit(f"{icon_name} does not use the uploaded CUTAWAN logo.")

for launch_file in launch_files:
    content = launch_file.read_text()
    if "@mipmap" in content or "launch_image" in content:
        raise SystemExit(f"Old static artwork remains in {launch_file}")

print("Verified blank native launch screen, transparent Android 12 splash icon, and new adaptive launcher icon.")
PY

MAIN_ACTIVITY_DIR="android/app/src/main/kotlin/com/m5ham3ds/cutawan_mobile"
mkdir -p "$MAIN_ACTIVITY_DIR"
install -m 0644 "$SCRIPT_DIR/android/MainActivity.kt" "$MAIN_ACTIVITY_DIR/MainActivity.kt"
install -m 0644 "$SCRIPT_DIR/android/NativeRenderEngine.kt" "$MAIN_ACTIVITY_DIR/NativeRenderEngine.kt"
install -m 0644 "$SCRIPT_DIR/android/NativeRenderWorker.kt" "$MAIN_ACTIVITY_DIR/NativeRenderWorker.kt"

# Preserve the Media3 instrumentation test and its deterministic source fixture.
ANDROID_TEST_DIR="android/app/src/androidTest/kotlin/com/m5ham3ds/cutawan_mobile"
ANDROID_TEST_ASSETS_DIR="android/app/src/androidTest/assets"
mkdir -p "$ANDROID_TEST_DIR" "$ANDROID_TEST_ASSETS_DIR"
install -m 0644 "$SCRIPT_DIR/android/androidTest/Media3CompositionParityTest.kt" "$ANDROID_TEST_DIR/Media3CompositionParityTest.kt"
install -m 0644 "$SCRIPT_DIR/android/test-fixtures/red-blue-transition.mp4" "$ANDROID_TEST_ASSETS_DIR/red-blue-transition.mp4"

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

# Expose only CUTAWAN-owned exports through FileProvider for older Android versions.
python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
source = manifest.read_text()
provider = '''        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/cutawan_file_paths" />
        </provider>
'''
if "androidx.core.content.FileProvider" not in source:
    application_end = source.find("</application>")
    if application_end < 0:
        raise SystemExit("Could not locate Android application closing element for FileProvider.")
    source = source[:application_end] + provider + source[application_end:]
manifest.write_text(source)

xml_dir = Path("android/app/src/main/res/xml")
xml_dir.mkdir(parents=True, exist_ok=True)
paths = xml_dir / "cutawan_file_paths.xml"
paths.write_text('''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path name="cutawan_external_exports" path="Movies/CUTAWAN/" />
    <files-path name="cutawan_internal_exports" path="CUTAWAN/" />
</paths>
''')
verified = manifest.read_text()
xml = paths.read_text()
if "androidx.core.content.FileProvider" not in verified or "@xml/cutawan_file_paths" not in verified:
    raise SystemExit("FileProvider declaration was not applied.")
if "Movies/CUTAWAN/" not in xml or 'path="CUTAWAN/"' not in xml:
    raise SystemExit("FileProvider export paths are missing or too broad.")
print("Verified FileProvider access is limited to CUTAWAN-owned export folders.")
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
import re

kts = Path('android/app/build.gradle.kts')
groovy = Path('android/app/build.gradle')
if kts.is_file():
    path = kts
    dependencies = [
        '    implementation("androidx.media3:media3-transformer:1.11.1")',
        '    implementation("androidx.media3:media3-effect:1.11.1")',
        '    implementation("androidx.media3:media3-common:1.11.1")',
        '    implementation("androidx.work:work-runtime:2.12.0")',
        '    androidTestImplementation("androidx.test:core:1.7.0")',
        '    androidTestImplementation("androidx.test:runner:1.3.0")',
        '    androidTestImplementation("androidx.test.ext:junit:1.3.0")',
    ]
elif groovy.is_file():
    path = groovy
    dependencies = [
        '    implementation "androidx.media3:media3-transformer:1.11.1"',
        '    implementation "androidx.media3:media3-effect:1.11.1"',
        '    implementation "androidx.media3:media3-common:1.11.1"',
        '    implementation "androidx.work:work-runtime:2.12.0"',
        '    androidTestImplementation "androidx.test:core:1.7.0"',
        '    androidTestImplementation "androidx.test:runner:1.3.0"',
        '    androidTestImplementation "androidx.test.ext:junit:1.3.0"',
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
        elif 'androidx.work:' in dependency:
            expected = 'androidx.work:work-runtime:2.12.0'
        elif 'androidx.test:core:' in dependency:
            expected = 'androidx.test:core:1.7.0'
        elif 'androidx.test:runner:' in dependency:
            expected = 'androidx.test:runner:1.3.0'
        else:
            expected = 'androidx.test.ext:junit:1.3.0'
        if expected not in source:
            lines.insert(block_index + 1, dependency)
source = chr(10).join(lines) + chr(10)
required_dependencies = (
    'androidx.media3:media3-transformer:1.11.1',
    'androidx.media3:media3-effect:1.11.1',
    'androidx.media3:media3-common:1.11.1',
    'androidx.work:work-runtime:2.12.0',
    'androidx.test:core:1.7.0',
    'androidx.test:runner:1.3.0',
    'androidx.test.ext:junit:1.3.0',
)
for expected in required_dependencies:
    if expected not in source:
        raise SystemExit('Missing Android dependency: ' + expected)

runner_statement = (
    'testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"'
    if path.suffix == '.kts'
    else 'testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"'
)
if 'androidx.test.runner.AndroidJUnitRunner' not in source:
    default_config = re.search(r'(?m)^([ ]*)defaultConfig[ ]*[{][ ]*$', source)
    if not default_config:
        raise SystemExit(f'Could not locate defaultConfig block in {path}')
    line_end = source.find(chr(10), default_config.end())
    if line_end < 0:
        raise SystemExit(f'defaultConfig block has no following line in {path}')
    indent = default_config.group(1) + '    '
    source = (
        source[:line_end + 1] + indent + runner_statement + chr(10) +
        source[line_end + 1:]
    )
path.write_text(source)
print('Verified Media3, WorkManager and AndroidX instrumentation dependencies.')
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
