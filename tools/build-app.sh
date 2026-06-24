#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"

if ! command -v gradle >/dev/null 2>&1; then
  echo "gradle must be available on PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

(cd "$ROOT_DIR/app" && gradle --no-daemon assembleDebug)
cp "$ROOT_DIR/app/build/outputs/apk/debug/app-debug.apk" \
  "$OUT_DIR/anland-termux-debug.apk"

echo "Built $OUT_DIR/anland-termux-debug.apk"
