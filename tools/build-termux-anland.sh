#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
SRC_DIR="$ROOT_DIR/termux/anland"
OUTPUT="$OUT_DIR/anland"

is_termux() {
  [[ "${PREFIX:-}" == /data/data/com.termux/files/usr ]] ||
    [[ -d /data/data/com.termux/files/usr && "$(uname -o 2>/dev/null || true)" == Android ]]
}

mkdir -p "$OUT_DIR"

if is_termux; then
  make -C "$SRC_DIR" clean
  make -C "$SRC_DIR"
  cp "$SRC_DIR/anland" "$OUTPUT"
  make -C "$SRC_DIR" clean
else
  CC="${CC:-aarch64-linux-android21-clang}"
  if ! command -v "$CC" >/dev/null 2>&1; then
    echo "NDK clang not found on PATH: $CC" >&2
    exit 1
  fi

  "$CC" -O2 -Wall -Wextra -Wpedantic -std=c11 \
    "$SRC_DIR/anland.c" \
    "$SRC_DIR/common/socket_utils.c" \
    -o "$OUTPUT"
fi

echo "Built $OUTPUT"
