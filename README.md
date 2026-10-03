# FretNote

**English** · [简体中文](README.zh-CN.md)

[![macOS build and tests](https://github.com/lele94218/FretNote/actions/workflows/build.yml/badge.svg)](https://github.com/lele94218/FretNote/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)

An offline macOS app for learning the guitar fretboard and reading sheet music, with real-time audio pitch detection.

Connect a guitar through an audio interface, read the note, and play it. FretNote checks the pitch and keeps a local learning history. Built with SwiftUI and Core Audio, with a minimal black-and-white interface.

[Download for macOS](https://github.com/lele94218/FretNote/releases/latest) · [Report an issue](https://github.com/lele94218/FretNote/issues)

## Screenshots

Actual app views rendered with demo data; no personal learning records are shown.

### Sight-reading · Light

![Sight-reading with staff notation and a six-string fretboard](docs/screenshots/sight-reading-light.jpg)

### Melody and position hint · Dark

![Short melody with the current note highlighted on the fretboard](docs/screenshots/fretboard-dark.jpg)

### Learning history

![Learning history with cumulative statistics and session results](docs/screenshots/learning-history.jpg)

## Features

- **Note-name practice:** choose one or more strings. Each question specifies a string; find the named note anywhere from the open string to fret 21. Any playable octave of that note on the requested string is accepted.
- **Sight-reading:** read a note on the staff and find it within a selected position, across all six strings. The fretboard stays visible; hints reveal a reference position.
- **Short melodies:** play 3–5 notes within a fixed position, checked one note at a time for pitch and order.
- **Position practice:** four consecutive frets by default, with an optional custom range, up to fret 21. Optionally practice only natural notes.
- **Learning history:** cumulative accuracy and response time, session history, hints, skips, and prioritized review. Each completed answer is saved automatically.
- **Native macOS UI:** light, dark, and system themes; adjustable text size from 100% to 175%; proportional staff and fretboard rendering. Practice fits in one window; history uses pagination.
- **Offline audio:** processing happens locally in memory. No audio recording, uploads, accounts, or runtime network dependency.

The app interface is currently in **Simplified Chinese**. Documentation is available in both languages.

## Download and install

Download `FretNote-v0.2.0-macOS-arm64.zip` from [Releases](https://github.com/lele94218/FretNote/releases/latest), unzip it, and drag `FretNote.app` into Applications.

- **Release requirements:** Apple Silicon Mac (M series), macOS 13 or later.
- **Intel Macs:** no prebuilt release yet. Building from source may work but has not been verified.
- **Signing:** builds are ad-hoc signed, without Apple Developer ID signing or notarization. macOS may block the first launch. Follow [Apple's guidance](https://support.apple.com/102445) only after verifying the download source, or build from source.

## Getting started

1. Connect your guitar to an audio interface. Use standard tuning: **E2 A2 D3 G3 B3 E4**, from string 6 to string 1, and a clean signal.
2. Open FretNote and select your device and input channel in **Settings → Audio Input** (`设置 → 音频输入`). Microphone input is also supported, though an interface provides a cleaner signal.
3. Click **Start Listening** (`开始监听`) and allow microphone access. macOS requires this permission for audio interfaces too.
4. Play a few isolated notes to check the level and detected pitch, then click **Start Practice** (`开始练习`).
5. Complete a 20-note session, or finish early. Mistakes, hints, and skips increase the priority of those notes in future practice.

The default position is frets 1–4. Selecting fret 5 moves it to frets 5–8. Custom ranges can include open strings. Staff notation follows guitar convention: **written one octave above sounding pitch**. The small 8 beneath the treble clef indicates this transposition.

| Shortcut | Action |
| --- | --- |
| `⌘Return` | Start / end practice |
| `⇧⌘H` | Show position hint |
| `⌘→` | Skip note |
| `⇧⌘I` | Start / stop listening |
| `⌘,` | Settings |
| `⌃⌘S` | Toggle sidebar |

## Detection limits

- **Single notes only.** Chords, rhythm, bends, and slides are not evaluated.
- Staff and melody modes require the correct sounding pitch and octave. Note-name mode accepts matching pitch classes within the requested string's playable range.
- Audio cannot reliably determine the physical string or fret when multiple positions produce the same pitch. Follow the displayed position yourself.
- Detection requires a stable pitch, allowing approximately ±40 cents. Unclear input and noise do not count as wrong answers.
- Mute between repeated notes when needed. Sustained notes do not repeatedly advance the exercise.
- Disable distortion, reverb, and delay, and mute unused strings. Harmonics and overlapping notes can cause errors.
- The default noise gate is −45 dBFS. Stop listening before adjusting it. Reduce interface gain if the input clips; refresh devices and restart listening after device or sample-rate changes.

Automated tests use synthetic signals. Accuracy has not been benchmarked against a representative set of real guitar recordings.

## Local data

Learning records are stored at:

```text
~/Library/Application Support/FretNote/progress.json
```

Sessions record their date, mode, string or fret range, natural-note setting, answer count, first-attempt accuracy, average response time, hints, and skips. Completed answers survive an early stop or app exit. Empty sessions are omitted.

Older aggregate statistics are preserved, but historical session details cannot be reconstructed. Proficiency is currently shared across practice modes and keyed by string and fret. Review uses weighted sampling, so notes that are not yet due may also appear. Unreadable records are preserved rather than overwritten.

## Build from source

Requires macOS 13+ and a Swift 5.9+ toolchain (Xcode / Command Line Tools). No third-party code dependencies. The bundled Bravura notation font works offline without system installation.

```bash
git clone https://github.com/lele94218/FretNote.git
cd FretNote
swift test
bash scripts/build-app.sh
open "$HOME/Applications/FretNote.app"
```

The script builds for the host architecture and installs into `~/Applications/FretNote.app`. It closes a running copy before updating. Intermediate app bundles are created under hidden `.build` storage and removed automatically; the old `dist/FretNote.app` is removed after successful installation to avoid duplicate app entries. Learning data stays in Application Support.

Use the packaged `.app` for audio testing so macOS receives the correct application identity and microphone permission description. Re-signing may prompt for permission again. Open `Package.swift` in Xcode to edit the project. GitHub Actions runs tests and uploads an app ZIP.

Optional UI snapshots (briefly opens test windows; does not access audio):

```bash
FRETNOTE_SNAPSHOT_DIR=/tmp/fretnote-preview swift test --filter testRender
```

## Project structure

```text
Sources/FretNoteCore/   Pitch detection, note gating, fretboard mapping, exercises
Sources/FretNoteApp/    SwiftUI, notation, Core Audio input, local learning records
Tests/                 Synthetic audio and practice-state tests
Resources/             App metadata and icon source
scripts/               App packaging and reproducible icon generation
```

Audio pipeline: Core Audio device enumeration → AVAudioEngine input tap → selected mono channel → background downsampling → YIN pitch estimation → stable note events → practice state machine.

Notation uses [Steinberg Bravura](https://github.com/steinbergmedia/bravura) and its SMuFL metadata. Noteheads, clefs, and accidentals use font outlines, with stems aligned to the provided anchors.

## Contributing

Issues and pull requests are welcome. Run `swift test` before submitting changes. For audio issues, include your macOS version, interface, input settings, and reproduction steps. Do not commit personal learning records, credentials, or recordings you do not have permission to share.

Future directions include real-guitar regression samples, separate sight-reading proficiency, rhythm exercises, and expanded notation support.

## License

Project code is released under the [MIT License](LICENSE). The bundled Bravura font and associated resources retain their upstream license; see [Bravura-LICENSE.txt](Sources/FretNoteApp/Resources/Bravura-LICENSE.txt).
