#!/usr/bin/env bash
set -euo pipefail

FIXTURE="tooling/android/test-fixtures/red-blue-transition.mp4"
ASSET_DIR="assets/testdata"
GRID_PNG="$ASSET_DIR/clip-preview-grid.png"
GRID_VIDEO="$ASSET_DIR/clip-preview-grid.mp4"
mkdir -p "$(dirname "$FIXTURE")" "$ASSET_DIR"

# A fixed 4x3 color grid makes crop position measurable at interior pixels.
# Generate PNG with Python's standard library, without extra packages.
python3 - "$GRID_PNG" <<'PY'
import struct
import sys
import zlib

path = sys.argv[1]
width, height = 320, 180
colors = [
    (230, 42, 42), (45, 185, 65), (42, 92, 230), (235, 195, 42),
    (195, 45, 205), (35, 185, 190), (235, 112, 28), (115, 72, 215),
    (112, 178, 38), (35, 125, 180), (185, 95, 132), (70, 78, 88),
]

def chunk(kind, payload):
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)

rows = bytearray()
for y in range(height):
    rows.append(0)
    row = bytearray()
    for x in range(width):
        column = min(3, x * 4 // width)
        line = min(2, y * 3 // height)
        color = colors[line * 4 + column]
        if x % 80 < 2 or y % 60 < 2:
            color = (248, 248, 248)
        row.extend(color)
    rows.extend(row)

png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    + chunk(b"IEND", b"")
)
with open(path, "wb") as output:
    output.write(png)
print(f"Generated deterministic {width}x{height} crop grid: {path}")
PY

# Repeat the static grid for two seconds. Media3 export is compared to this
# same image through the exact FittedBox widget used by ClipEditorPage.
ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -framerate 15 -i "$GRID_PNG" -t 2 \
  -vf "fps=15,format=yuv420p" -an \
  -c:v libx264 -profile:v baseline -level 3.0 \
  -preset ultrafast -tune zerolatency -crf 12 \
  -g 15 -keyint_min 15 -sc_threshold 0 \
  -movflags +faststart "$GRID_VIDEO"

# Deterministic silent source: one second of solid red followed by one second
# of solid blue. The instrumentation test samples the native Media3 MP4 output.
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "color=c=red:s=160x120:r=15:d=1" \
  -f lavfi -i "color=c=blue:s=160x120:r=15:d=1" \
  -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p" \
  -an -c:v libx264 -profile:v baseline -level 3.0 \
  -preset ultrafast -tune zerolatency -crf 18 \
  -g 15 -keyint_min 15 -sc_threshold 0 \
  -movflags +faststart "$FIXTURE"

python3 - "$FIXTURE" <<'PY'
import json
import subprocess
import sys

fixture = sys.argv[1]
completed = subprocess.run(
    [
        "ffprobe", "-v", "error",
        "-show_entries",
        "format=duration:stream=codec_name,width,height,r_frame_rate,pix_fmt",
        "-select_streams", "v:0",
        "-of", "json",
        fixture,
    ],
    check=True,
    capture_output=True,
    text=True,
)
metadata = json.loads(completed.stdout)
streams = metadata.get("streams", [])
if len(streams) != 1:
    raise SystemExit(f"Expected one video stream, found {len(streams)}")
stream = streams[0]
duration = float(metadata.get("format", {}).get("duration", 0))
expected = {
    "codec_name": "h264",
    "width": 160,
    "height": 120,
    "r_frame_rate": "15/1",
    "pix_fmt": "yuv420p",
}
for field, value in expected.items():
    if stream.get(field) != value:
        raise SystemExit(
            f"Invalid Media3 fixture {field}: expected {value}, got {stream.get(field)}"
        )
if not 1.95 <= duration <= 2.05:
    raise SystemExit(f"Expected a 2-second fixture, got {duration:.3f}s")
print(f"Validated deterministic Media3 test fixture: {duration:.3f}s, {stream}")
PY

sha256sum "$FIXTURE"

python3 - "$GRID_VIDEO" <<'PY'
import json
import subprocess
import sys

fixture = sys.argv[1]
probe = subprocess.run(
    [
        "ffprobe", "-v", "error",
        "-show_entries",
        "format=duration:stream=codec_name,width,height,r_frame_rate,pix_fmt",
        "-select_streams", "v:0",
        "-of", "json",
        fixture,
    ],
    check=True,
    capture_output=True,
    text=True,
)
metadata = json.loads(probe.stdout)
streams = metadata.get("streams", [])
if len(streams) != 1:
    raise SystemExit(f"Expected one crop-grid video stream, found {len(streams)}")
stream = streams[0]
duration = float(metadata.get("format", {}).get("duration", 0))
expected = {
    "codec_name": "h264",
    "width": 320,
    "height": 180,
    "r_frame_rate": "15/1",
    "pix_fmt": "yuv420p",
}
for field, value in expected.items():
    if stream.get(field) != value:
        raise SystemExit(
            f"Invalid crop-grid fixture {field}: expected {value}, got {stream.get(field)}"
        )
if not 1.95 <= duration <= 2.05:
    raise SystemExit(f"Expected a 2-second crop-grid fixture, got {duration:.3f}s")
print(f"Validated preview parity fixture: {duration:.3f}s, {stream}")
PY
sha256sum "$GRID_PNG" "$GRID_VIDEO"
