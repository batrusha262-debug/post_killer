#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
ARCHITECTURE="${2:?pass target architecture (arm64 or x86_64)}"
APP_PATH="apps/client_flutter/build/macos/Build/Products/Release/Post Killer.app"

case "$ARCHITECTURE" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported macOS architecture: $ARCHITECTURE" >&2
    exit 2
    ;;
esac

OUTPUT="dist/Post-Killer-${VERSION}-macos-${ARCHITECTURE}.dmg"

test -d "$APP_PATH"

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"

if [[ "$ARCHITECTURES" != "$ARCHITECTURE" ]]; then
  echo "Expected a native $ARCHITECTURE app only, found: $ARCHITECTURES" >&2
  exit 1
fi

mkdir -p dist
hdiutil create -volname "Post Killer" -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT"
