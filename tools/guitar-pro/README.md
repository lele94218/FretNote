# Offline Guitar Pro parser

The macOS app evaluates the bundled `GuitarProImporter.js` in a private JavaScriptCore VM on a background task. No browser, network access, Node or Python is required on the user's Mac. Foundation supplies the text encoding bridge.

To regenerate from the pinned dependencies:

```sh
cd tools/guitar-pro
npm ci
npm run build
```

alphaTab 1.8.4 is used unmodified under MPL-2.0. Its source is available at https://github.com/coderline/alphaTab/tree/v1.8.4 and in the pinned npm package. The license is bundled in the application as `alphaTab-LICENSE.txt`. The entry point imports the core module to avoid browser initialization. The adapter uses alphaTab's generated MIDI tick lookup to expand repeats and retain rhythmic timing and tempo changes; the same MIDI generation also supplies note on/off, controller, program and per-note pitch-bend events to the native renderer.

Supported UI input: GP3/4/5, GPX, GP. Rendering currently accepts standard-tuned six-string guitar tracks with no capo, fret 0–21, first staff. Unsupported tracks remain visible as activity rows, but cannot be selected for fretboard playback. Meter-aware beat timestamps are exported across repeated bars and tempo changes for the audio-clock metronome. Bends, slides, ties and legato are retained and indicated. Generated MIDI events drive audio bends and note lengths; bend amount and release indicators follow the same per-note MIDI wheel/RPN pitch range as the synth, with bar-selection and speed offsets accounted for. These are score playback guides, not measured-input judgments. The imported score does not enter learning records.

`Tests/FretNoteAppTests/Fixtures/timing.gp5` is an original test fixture: A4 quarter, eighth rest, two-note eighth, C5 half, repeated; then E5 whole at half tempo with a bend. `timing.gp` is an alphaTab GP7 export of the same fixture. No commercial song is bundled or published.

## MIDI audio

`Sources/CTinySoundFont/tsf.h` is vendored unmodified from TinySoundFont commit `853a0a171759f1ddba0de1442133a75912bbeffa`, MIT license. The small C wrapper gives each original MIDI channel/key its own virtual synth channel so simultaneous notes can bend independently. `sonivox.sf2` is copied from the pinned alphaTab npm distribution with its Apache-2.0 notice and license.

Audio is rendered to a mono 44.1 kHz PCM buffer on a cancellable worker, then played by AVAudioEngine/AVAudioPlayerNode. No Node, Python, external synth, sound bank download, network or microphone is needed. The view reads the audio sample position with output-latency compensation; camera work cannot block synthesis or audio scheduling. Playback caches the last track/range/speed. Speed changes resynthesize event times, preserving pitch. Playback duration is limited to 20 minutes to bound PCM memory. Only the selected compatible guitar track plays; backing-track mixing, MIDI export and user SoundFonts are not included.

Use `FRETNOTE_MIDI_DEVICE_TEST=1 swift test --filter ScoreMIDITests` to check the actual output-device clock and looping at zero volume. Offline tests validate waveform pitch (including bends), rest tails, speed, repeats and cut-state restoration without opening an output device.
