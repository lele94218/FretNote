# FretNote development

- Native macOS SwiftUI app; maintain offline operation and avoid audio uploads.
- Sounding MIDI is the source of truth. Guitar staff notation is one octave higher.
- Never claim pitch detection validates the physical string or fret.
- Keep signal analysis off the main thread. Treat ambiguous audio separately from wrong notes.
- After changes to detection, exercises, or scoring, run `swift test`. Package with `bash scripts/build-app.sh` for microphone tests.
- Use temporary paths in tests; never modify the user's real learning records.
- Update README when behavior or setup changes. Do not commit `.build`, `dist`, or user recordings.
