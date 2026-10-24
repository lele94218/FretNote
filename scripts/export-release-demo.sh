#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUTPUT="$PWD/.build/release-demo"
mkdir -p "$OUTPUT" docs/demo
PACKAGE_RESOURCE_BUNDLE_PATH="$PWD/.build/out/Products/Debug" \
FRETNOTE_DEMO_EXPORT="$OUTPUT" FRETNOTE_DEMO_SCORE="$PWD/docs/demo/fretnote-demo.gp" \
swift test --filter ReleaseDemoTests.testExportReleaseDemo
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$OUTPUT/%04d.jpg" -i "$OUTPUT/audio.wav" \
  -c:v libx264 -crf 21 -pix_fmt yuv420p -c:a aac -b:a 160k -shortest -movflags +faststart "$OUTPUT/FretNote-v0.4.0-demo.mp4"
ffmpeg -hide_banner -loglevel error -y -i "$OUTPUT/FretNote-v0.4.0-demo.mp4" \
  -filter_complex '[0:v]fps=15,scale=880:-1,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' \
  -loop 0 docs/demo/fretboard-player.gif
cp "$OUTPUT/0180.jpg" docs/demo/fretboard-player.jpg
