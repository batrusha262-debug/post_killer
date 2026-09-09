#!/usr/bin/env bash
set -euo pipefail

# This release runner is pinned to Ubuntu 22.04 amd64. Only Ubuntu packages
# are needed; unrelated preinstalled Chrome/Microsoft sources must not gate it.
# Source overrides are scoped to these commands and preserve APT verification.
sources=$(mktemp)
trap 'rm -f "$sources"' EXIT
cat > "$sources" <<'SOURCES'
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://archive.ubuntu.com/ubuntu jammy main universe
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://archive.ubuntu.com/ubuntu jammy-updates main universe
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://security.ubuntu.com/ubuntu jammy-security main universe
SOURCES
chmod 644 "$sources"

apt_options=(
  -o "Dir::Etc::sourcelist=$sources"
  -o "Dir::Etc::sourceparts=-"
  -o "Acquire::Retries=3"
)
sudo apt-get "${apt_options[@]}" update
sudo apt-get "${apt_options[@]}" install --yes \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
