# Media3 transition test fixture

The binary fixture is generated during CI by:

`tooling/generate_media3_transition_fixture.sh`

It uses FFmpeg's `color` lavfi source and H.264 encoder to create a silent MP4 with:

- 160×120 video at 15 fps
- Solid red for the first second, followed by solid blue for the second second
- H.264 Baseline, `yuv420p`, approximately 2 seconds

The generator validates the container and stream properties with `ffprobe` before the Android project generator copies the file into `androidTest/assets`. The instrumentation test invokes the real Media3 composition renderer and samples frames before, during and after a 600 ms dip-to-black transition.
