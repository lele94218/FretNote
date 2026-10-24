#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
STAGING=$(mktemp -d "$PWD/.build/release-package.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$HOME/Applications/FretNote.app" "$STAGING/FretNote.app"
# Local web fonts are not redistributable. The app falls back to bundled OFL Inter.
find "$STAGING/FretNote.app" -type f -name 'FavoritSSENSE-*.ttf' -delete
codesign --force --deep --sign - --identifier com.lele94218.FretNote "$STAGING/FretNote.app"
codesign --verify --deep --strict "$STAGING/FretNote.app"
ARCHIVE="FretNote-v${VERSION}-macOS-${ARCH}.zip"
ditto -c -k --keepParent "$STAGING/FretNote.app" "$PWD/dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt)
echo "Release archive: dist/$ARCHIVE"
