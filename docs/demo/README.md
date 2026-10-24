# Demo assets

The README preview shows bars 5–8 of the user's supplied **Endless Rain solo** score. Only the rendered excerpt is published; its source score is not included. The preview uses the application's vector guitar, scale analysis and pitch-driven bend renderer in a compact presentation layout. The camera moves ahead of position changes. The bar strip is rendered without a scroll view for deterministic offscreen export.

`fretnote-demo.gp` is a separate original two-bar practice phrase derived from the project's timing fixture. It remains available for anyone to try without the private solo score.

## Export

Requires macOS, Swift and FFmpeg. To export your own locally held score, select an inclusive bar range:

```sh
FRETNOTE_VIDEO_NAME=FretNote-solo-preview.mp4 \
bash scripts/export-release-demo.sh /path/to/your-solo.gp 5 8
```

Without arguments, the script uses the original bundled demo. Exports are 1440 × 810 at 30 fps. GIF encoding uses lossless PNG frames and a 256-color palette without downscaling. The H.264/AAC video is saved under `.build/release-demo/`; frames remain in a temporary directory under `.build/`. The GIF plays inline on GitHub; MP4 is a downloadable release attachment.

To package a public release, run `bash scripts/package-release.sh`. It removes local non-redistributable fonts from the archive, re-signs the app, and writes SHA-256 checksums. The installed local app keeps its local fonts.
