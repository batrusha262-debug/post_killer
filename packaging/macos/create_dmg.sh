#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
APP_PATH="apps/client_flutter/build/macos/Build/Products/Release/Post Killer.app"
OUTPUT="dist/Post-Killer-${VERSION}-macos.dmg"

test -d "$APP_PATH"

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"

case " $ARCHITECTURES " in
  *" arm64 "*" x86_64 "*) ;;
  *)
    echo "Expected a universal arm64 + x86_64 app, found: $ARCHITECTURES" >&2
    echo "Build with: flutter build macos --release --macos-archs=arm64,x86_64" >&2
    exit 1
    ;;
esac

mkdir -p dist
hdiutil create -volname "Post Killer" -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT"
