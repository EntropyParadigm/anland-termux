#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"

mkdir -p "$OUT_DIR"

make -C "$ROOT_DIR/termux/anland" clean
make -C "$ROOT_DIR/termux/anland"
cp "$ROOT_DIR/termux/anland/anland" "$OUT_DIR/anland"
make -C "$ROOT_DIR/termux/anland" clean

echo "Built $OUT_DIR/anland"
