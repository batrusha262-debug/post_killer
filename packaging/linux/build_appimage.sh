#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
BUNDLE="apps/client_flutter/build/linux/x64/release/bundle"
APPDIR="dist/PostKiller.AppDir"
TOOL="dist/appimagetool-x86_64.AppImage"
OUTPUT="dist/Post-Killer-${VERSION}-linux-x86_64.AppImage"

test -d "$BUNDLE"
rm -rf "$APPDIR"
install -d "$APPDIR/usr/bin"
cp -R "$BUNDLE/." "$APPDIR/usr/bin/"
cat > "$APPDIR/post-killer.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Post Killer
Exec=post_killer
Icon=post-killer
Categories=Development;Network;
Terminal=false
EOF
cp apps/client_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png "$APPDIR/post-killer.png"
curl --fail --location --silent --show-error \
  --output "$TOOL" \
  https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x "$TOOL"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"
