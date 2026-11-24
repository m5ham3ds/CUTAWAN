#!/usr/bin/env bash
set -euo pipefail

FIXTURE="tooling/android/test-fixtures/red-blue-transition.mp4"
mkdir -p "$(dirname "$FIXTURE")"

# Deterministic silent source: one second of solid red followed by one second
# of solid blue. The instrumentation test samples the native Media3 MP4 output.
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "color=c=red:s=160x120:r=15:d=1" \
  -f lavfi -i "color=c=blue:s=160x120:r=15:d=1" \
  -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p" \
  -an -c:v libx264 -profile:v baseline -level 3.0 \
  -preset ultrafast -tune zerolatency -crf 0 \
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
