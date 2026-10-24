# Demo assets

`fretnote-demo.gp` is an original two-bar practice phrase derived from the project's original timing fixture. It demonstrates note playback, repeats, a tempo change, vibrato and a bend with vibrato. No commercial song or personal learning data is included.

The preview uses the application's actual vector guitar and bend renderer in a compact presentation layout. The sparse demo is presented in E minor when the automatic analyzer has insufficient evidence. The bar strip is rendered without a scroll view for deterministic offscreen export.

Run on macOS with Swift and FFmpeg:

```sh
bash scripts/export-release-demo.sh
```

This exports a 30 fps H.264/AAC MP4 to `.build/release-demo/`, a lightweight 15 fps GIF for inline GitHub README playback, and a JPEG poster. The MP4 is uploaded as a release attachment; README previews use the GIF, not a repository MP4 link.

To package a public release, run `bash scripts/package-release.sh`. It removes local non-redistributable fonts from the archive, re-signs the app, and writes SHA-256 checksums. The installed local app keeps its local fonts.
