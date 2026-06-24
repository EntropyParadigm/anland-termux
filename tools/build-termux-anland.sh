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

resolve_ndk_clang() {
  local default_clang="aarch64-linux-android21-clang"
  local ndk_clang="${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/linux-x86_64/bin/$default_clang"

  if [[ -n "${CC:-}" ]]; then
    printf '%s\n' "$CC"
  elif command -v "$default_clang" >/dev/null 2>&1; then
    command -v "$default_clang"
  elif [[ -n "${ANDROID_NDK_HOME:-}" && -x "$ndk_clang" ]]; then
    printf '%s\n' "$ndk_clang"
  else
    return 1
  fi
}

mkdir -p "$OUT_DIR"

if is_termux; then
  make -C "$SRC_DIR" clean
  make -C "$SRC_DIR"
  cp "$SRC_DIR/anland" "$OUTPUT"
  make -C "$SRC_DIR" clean
else
  CC="$(resolve_ndk_clang)" || {
    echo "NDK clang not found: aarch64-linux-android21-clang" >&2
    echo "Expected it on PATH or at:" >&2
    echo '  $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang' >&2
    exit 1
  }

  "$CC" -O2 -Wall -Wextra -Wpedantic -std=c11 \
    "$SRC_DIR/anland.c" \
    "$SRC_DIR/common/socket_utils.c" \
    -o "$OUTPUT"
fi

echo "Built $OUTPUT"
