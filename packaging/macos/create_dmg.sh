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
PACKAGED_APP="$(mktemp -d)/Post Killer.app"

test -d "$APP_PATH"

cp -R "$APP_PATH" "$PACKAGED_APP"

# Flutter's normal release build is universal. Keep the requested native slice
# in every universal Mach-O within the copied app, including embedded plugins
# and frameworks, so Intel never has to execute an Apple Silicon binary and
# vice versa.
while IFS= read -r -d '' file; do
  architectures="$(lipo -archs "$file" 2>/dev/null || true)"
  if [[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]; then
    lipo -thin "$ARCHITECTURE" "$file" -output "$file.thin"
    mv "$file.thin" "$file"
  fi
done < <(find "$PACKAGED_APP" -type f -perm -111 -print0)

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PACKAGED_APP/Contents/Info.plist")"
EXECUTABLE_PATH="$PACKAGED_APP/Contents/MacOS/$EXECUTABLE_NAME"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"

if [[ "$ARCHITECTURES" != "$ARCHITECTURE" ]]; then
  echo "Expected a native $ARCHITECTURE app only, found: $ARCHITECTURES" >&2
  exit 1
fi

mkdir -p dist
hdiutil create -volname "Post Killer" -srcfolder "$PACKAGED_APP" -ov -format UDZO "$OUTPUT"
