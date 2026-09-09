#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?pass package version}"
BUNDLE="apps/client_flutter/build/linux/x64/release/bundle"
ROOT="dist/deb-root"

test -d "$BUNDLE"
rm -rf "$ROOT"
install -d "$ROOT/DEBIAN" "$ROOT/opt/post-killer" "$ROOT/usr/share/applications"
cp -R "$BUNDLE/." "$ROOT/opt/post-killer/"
cat > "$ROOT/DEBIAN/control" <<EOF
Package: post-killer
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Maintainer: Post Killer contributors <batrusha262@gmail.com>
Description: Local-first desktop HTTP client
EOF
cat > "$ROOT/usr/share/applications/post-killer.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Post Killer
Exec=/opt/post-killer/post_killer
Categories=Development;Network;
Terminal=false
EOF
mkdir -p dist
dpkg-deb --build --root-owner-group "$ROOT" "dist/post-killer_${VERSION}_amd64.deb"
