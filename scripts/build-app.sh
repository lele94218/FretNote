#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
# Keep intermediate app bundles out of Launch Services discovery.
mkdir -p "$PWD/.build" "$PWD/dist" "$HOME/Applications"
STAGING_DIR="$(mktemp -d "$PWD/.build/app-package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="$STAGING_DIR/FretNote.app"
INSTALLED_APP="$HOME/Applications/FretNote.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FretNote" "$APP/Contents/MacOS/FretNote"
cp -R "$BIN_DIR/FretNote_FretNoteApp.bundle" "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/dist/AppIcon.iconset"
iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - --identifier com.lele94218.FretNote "$APP"
codesign --verify --deep --strict "$APP"
if pgrep -x FretNote >/dev/null; then
    osascript -e 'tell application id "com.lele94218.FretNote" to quit'
fi
ditto "$APP" "$INSTALLED_APP"
codesign --verify --deep --strict "$INSTALLED_APP"
# Remove the previous public build location only after installing successfully.
if [ -d "$PWD/dist/FretNote.app" ]; then
    "$LSREGISTER" -u "$PWD/dist/FretNote.app" || true
    rm -rf "$PWD/dist/FretNote.app"
fi
"$LSREGISTER" -f "$INSTALLED_APP"
echo "Installed: $INSTALLED_APP"
