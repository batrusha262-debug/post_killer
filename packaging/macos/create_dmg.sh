#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
APP_PATH="apps/client_flutter/build/macos/Build/Products/Release/Post Killer.app"
OUTPUT="dist/Post-Killer-${VERSION}-macos.dmg"

test -d "$APP_PATH"
mkdir -p dist
hdiutil create -volname "Post Killer" -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT"
