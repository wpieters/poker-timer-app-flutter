#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  flutter_bin="$FLUTTER_BIN"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  flutter_bin="$HOME/flutter/flutter/bin/flutter"
fi
"$flutter_bin" build web --release --no-web-resources-cdn "$@"
node scripts/generate-service-worker.cjs
