#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
APP_PATH="apps/client_flutter/build/macos/Build/Products/Release/Post Killer.app"
OUTPUT="dist/Post-Killer-${VERSION}-macos.dmg"

test -d "$APP_PATH"

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"

if [[ " $ARCHITECTURES " != *" arm64 "* || " $ARCHITECTURES " != *" x86_64 "* ]]; then
  echo "Expected a universal arm64 + x86_64 app, found: $ARCHITECTURES" >&2
  echo "Flutter macOS release builds include both architectures by default." >&2
  exit 1
fi

mkdir -p dist
hdiutil create -volname "Post Killer" -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT"
