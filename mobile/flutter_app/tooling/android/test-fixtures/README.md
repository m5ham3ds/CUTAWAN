# Media3 transition test fixture

- File: `red-blue-transition.mp4`
- SHA-256: `f190217b68573ce3d92c9aed6f00001c3d391e7fa439a26e6054ad12e630b3ff`
- Container: MP4
- Video: H.264 Baseline, 160×120, 15 fps, 2.0 seconds, yuv420p
- Content: solid red for the first second, then solid blue for the second second
- Audio: none
- Purpose: deterministic input for the Android Media3 composition instrumentation test. The test samples native-rendered output frames before, during and after a 600 ms dip-to-black transition.

The source is generated locally with FFmpeg's `color` lavfi filters and H.264 encoder. The file is committed so CI tests use the same byte-for-byte input on every run.
