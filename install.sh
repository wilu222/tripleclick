#!/usr/bin/env bash
# Installs the latest TripleClick release into /Applications.
# curl downloads aren't quarantined, so Gatekeeper doesn't block the first launch.
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/TripleClick.zip" \
  https://github.com/wilu222/tripleclick/releases/latest/download/TripleClick.zip

pkill -x TripleClick || true
rm -rf /Applications/TripleClick.app
ditto -x -k "$tmp/TripleClick.zip" /Applications
open /Applications/TripleClick.app
echo "Installed. Grant Accessibility access when macOS asks."
