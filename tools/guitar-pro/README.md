# Offline Guitar Pro parser

The macOS app evaluates the bundled `GuitarProImporter.js` in a private JavaScriptCore VM on a background task. No browser, network access, Node or Python is required on the user's Mac. Foundation supplies the text encoding bridge.

To regenerate from the pinned dependencies:

```sh
cd tools/guitar-pro
npm ci
npm run build
```

alphaTab 1.8.4 is used unmodified under MPL-2.0. Its source is available at https://github.com/coderline/alphaTab/tree/v1.8.4 and in the pinned npm package. The license is bundled in the application as `alphaTab-LICENSE.txt`. The entry point imports the core module to avoid browser initialization. The adapter uses alphaTab's generated MIDI tick lookup to expand repeats and retain rhythmic timing and tempo changes; this does not synthesize audio.

Supported UI input: GP3/4/5, GPX, GP. Rendering currently accepts standard-tuned six-string guitar tracks with no capo, fret 0–21, first staff. Unsupported tracks are omitted. Bends, slides, ties and legato are retained and indicated, but pitch curves are not animated or judged yet. The imported score does not enter learning records.

`Tests/FretNoteAppTests/Fixtures/timing.gp5` is an original test fixture: A4 quarter, eighth rest, two-note eighth, C5 half, repeated; then E5 whole at half tempo with a bend. `timing.gp` is an alphaTab GP7 export of the same fixture. No commercial song is bundled or published.
