# Offline Guitar Pro parser

The macOS app evaluates the bundled `GuitarProImporter.js` in a private JavaScriptCore VM on a background task. No browser, network access, Node or Python is required on the user's Mac. Foundation supplies the text encoding bridge.

To regenerate from the pinned dependencies:

```sh
cd tools/guitar-pro
npm ci
npm run build
```

alphaTab 1.8.4 is used under MPL-2.0. `build.mjs` generates a patched copy without changing the installed npm source: it preserves zero-valued GPIF bend midpoints and ignores unused middle fields beyond the bend destination. The exact source changes are recorded in that script; it fails if the pinned parser no longer matches. Its source is available at https://github.com/coderline/alphaTab/tree/v1.8.4 and in the pinned npm package. The license is bundled in the application as `alphaTab-LICENSE.txt`. The entry point imports the core module to avoid browser initialization. The adapter routes format-0 MIDI events by their original score-track identity, not MIDI container index. Each track’s virtual channels are mapped into 0–15 (preserving percussion channel 9) before synthesis; independent bend channels remain separate. Cached imports are versioned and automatically regenerated from locally archived originals. The adapter uses alphaTab's generated MIDI tick lookup to expand repeats and retain rhythmic timing and tempo changes; the same MIDI generation also supplies note on/off, controller, program and per-note pitch-bend events to the native renderer.

Supported UI input: GP3/4/5, GPX, GP. Rendering currently accepts standard-tuned six-string guitar tracks with no capo, fret 0–21, first staff. Other tracks play as independently mutable accompaniment but cannot guide the guitar fretboard. Meter-aware beat timestamps are exported across repeated bars and tempo changes for the audio-clock metronome. Bends, note/beat vibrato, slides, ties and legato are retained and indicated. Vibrato markers and strings follow interpolated MIDI pitch, including channel-wide beat vibrato. Generated MIDI events drive audio bends and note lengths; bend amount and release indicators follow the same per-note MIDI wheel/RPN pitch range as the synth, with bar-selection and speed offsets accounted for. These are score playback guides, not measured-input judgments. The imported score does not enter learning records.

`Tests/FretNoteAppTests/Fixtures/timing.gp5` is an original test fixture: A4 quarter, eighth rest, two-note eighth, C5 half, repeated; then E5 whole at half tempo with a bend. `timing.gp` is an alphaTab GP7 export of the same fixture. `vibrato.gp` derives from this original fixture with note-level slight, beat-level wide vibrato, and a whole-tone prebend with note vibrato. The adapter composes simultaneous bend and note vibrato into per-note MIDI events because alphaTab 1.8.4 otherwise chooses the bend alone. No commercial song is bundled or published.

## MIDI audio

`Sources/CTinySoundFont/tsf.h` is vendored unmodified from TinySoundFont commit `853a0a171759f1ddba0de1442133a75912bbeffa`, MIT license. The small C wrapper gives each original MIDI channel/key its own virtual synth channel so simultaneous notes can bend independently. `sonivox.sf2` is copied from the pinned alphaTab npm distribution with its Apache-2.0 notice and license.

Audio is rendered to a mono 44.1 kHz PCM buffer on a cancellable worker, then played by AVAudioEngine/AVAudioPlayerNode. No Node, Python, external synth, sound bank download, network or microphone is needed. The view reads the audio sample position with output-latency compensation; camera work cannot block synthesis or audio scheduling. Playback caches the last track/range/speed. Speed changes resynthesize event times, preserving pitch. Playback duration is limited to 20 minutes to bound PCM memory. Only the selected compatible guitar track plays; backing-track mixing, MIDI export and user SoundFonts are not included.

Use `FRETNOTE_MIDI_DEVICE_TEST=1 swift test --filter ScoreMIDITests` to check the actual output-device clock and looping at zero volume. Offline tests validate waveform pitch (including bends), rest tails, speed, repeats and cut-state restoration without opening an output device.

`multitrack.gp` is an original two-lead regression fixture with four quarter notes per lead, distinct pitches and virtual channels above 15. Tests verify event isolation, sounding pitch on both tracks and automatic cache upgrades.

## Bend timing

The adapter preserves the source bend control points across alphaTab's engraving
normalization, which otherwise removes intermediate holds from three/four-point
curves. MIDI synthesis and string animation use these same preserved curves.
Malformed time positions outside the note's 0–60 coordinate range are rejected
before MIDI generation. Import version 5 refreshes archived scores automatically.

`complex-bends.gp5` is an original regression fixture for delayed bends, independent
double bends, fractional pre-bends/releases, tied continuation and combined vibrato.
`invalid-bend-timing.gp5` deliberately exceeds the valid time range. Regenerate with
`create-bend-fixtures.py` in a Python environment containing PyGuitarPro; its model
uses time positions 0–12, which the library converts to the binary format's 0–60.
Tests also measure rendered pitch at normal and half speed.

`create-gp-bend-fixture.mjs` exports the native `.gp` regression fixture, including an early bend destination with an unused later middle field.
