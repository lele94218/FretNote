#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
# Keep intermediate app bundles out of Launch Services discovery.
mkdir -p "$PWD/.build" "$PWD/dist" "$HOME/Applications"
STAGING_DIR="$(mktemp -d "$PWD/.build/app-package.XXXXXX")"
INSTALL_DIR="$(mktemp -d "$HOME/Applications/.FretNote-install.XXXXXX")"
cleanup() {
    if [ ! -e "$HOME/Applications/FretNote.app" ] && [ -d "$INSTALL_DIR/previous.app" ]; then
        if ! mv "$INSTALL_DIR/previous.app" "$HOME/Applications/FretNote.app"; then
            echo "Could not restore previous app; retained at $INSTALL_DIR/previous.app" >&2
            return 1
        fi
    fi
    rm -rf "$STAGING_DIR" "$INSTALL_DIR"
}
trap cleanup EXIT
APP="$STAGING_DIR/FretNote.app"
INSTALLED_APP="$HOME/Applications/FretNote.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FretNote" "$APP/Contents/MacOS/FretNote"
cp -R "$BIN_DIR/FretNote_FretNoteApp.bundle" "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/dist/AppIcon.iconset"
iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - --identifier com.lele94218.FretNote "$APP"
codesign --verify --deep --strict "$APP"
if pgrep -x FretNote >/dev/null; then
    osascript -e 'tell application id "com.lele94218.FretNote" to quit'
fi
# Verify a fresh copy on the destination volume; never merge old bundle resources.
ditto "$APP" "$INSTALL_DIR/FretNote.app"
codesign --verify --deep --strict "$INSTALL_DIR/FretNote.app"
if [ -e "$INSTALLED_APP" ]; then
    mv "$INSTALLED_APP" "$INSTALL_DIR/previous.app"
fi
mv "$INSTALL_DIR/FretNote.app" "$INSTALLED_APP"
codesign --verify --deep --strict "$INSTALLED_APP"
# Remove the previous public build location only after installing successfully.
if [ -d "$PWD/dist/FretNote.app" ]; then
    "$LSREGISTER" -u "$PWD/dist/FretNote.app" || true
    rm -rf "$PWD/dist/FretNote.app"
fi
"$LSREGISTER" -f "$INSTALLED_APP"
echo "Installed: $INSTALLED_APP"
