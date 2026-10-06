#!/bin/bash
# Render the README screenshots into assets/: every Settings tab and a translation popup.
# The app draws its own views offscreen, so no Screen Recording permission is needed.
# The debug build is used because it is not sandboxed and may write into the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
.build/debug/LLMTranslator --screenshots "${1:-assets}"
