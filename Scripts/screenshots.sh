#!/bin/bash
# Render the README screenshots into assets/: every Settings tab and a translation popup.
# The app draws its own views offscreen, so no Screen Recording permission is needed.
# The debug build is used because it is not sandboxed and may write into the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
APP_VERSION=$(plutil -extract version raw app.json) \
    APP_REPOSITORY=$(plutil -extract repository raw app.json) \
    .build/debug/AppTranslatorSimple --screenshots "${1:-assets}"
