#!/bin/bash
# Redraw Resources/AppIcon.icns from Scripts/generate-icon.swift. build.sh copies it into the app.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=$(mktemp -d)/AppIcon.iconset
swift Scripts/generate-icon.swift "$ICONSET"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
