#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/FretNote.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FretNote" "$APP/Contents/MacOS/FretNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - --identifier com.lele94218.FretNote "$APP"
echo "Built: $APP"
