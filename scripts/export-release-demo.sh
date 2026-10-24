#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/release-demo docs/demo
OUTPUT=$(mktemp -d "$PWD/.build/demo-export.XXXXXX")
SOURCE="${1:-$PWD/docs/demo/fretnote-demo.gp}"
VIDEO_NAME="${FRETNOTE_VIDEO_NAME:-FretNote-v0.4.0-demo.mp4}"
PACKAGE_RESOURCE_BUNDLE_PATH="$PWD/.build/out/Products/Debug" \
FRETNOTE_DEMO_EXPORT="$OUTPUT" FRETNOTE_DEMO_SCORE="$SOURCE" \
FRETNOTE_DEMO_FIRST="${2:-1}" FRETNOTE_DEMO_LAST="${3:-}" \
swift test --filter ReleaseDemoTests.testExportReleaseDemo
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$OUTPUT/%04d.png" -i "$OUTPUT/audio.wav" \
  -c:v libx264 -crf 17 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart \
  ".build/release-demo/$VIDEO_NAME"
# Generate the GIF from lossless frames, without scaling or a second video compression pass.
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$OUTPUT/%04d.png" \
  -vf 'palettegen=max_colors=256:stats_mode=diff' -frames:v 1 "$OUTPUT/palette.png"
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$OUTPUT/%04d.png" -i "$OUTPUT/palette.png" \
  -lavfi 'paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle' -loop 0 docs/demo/fretboard-player.gif
ffmpeg -hide_banner -loglevel error -y -i "$OUTPUT/0180.png" -q:v 2 docs/demo/fretboard-player.jpg
printf 'Frames retained in %s\n' "$OUTPUT"
