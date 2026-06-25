#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
VERSION_NAME="$(awk -F'"' '/^[[:space:]]*versionName[[:space:]]*=/ { print $2; exit }' "$ROOT_DIR/app/build.gradle")"
APK_NAME="AnlandTermux-${VERSION_NAME}.apk"

if [[ -z "$VERSION_NAME" ]]; then
  echo "Could not read versionName from app/build.gradle" >&2
  exit 1
fi

if ! command -v gradle >/dev/null 2>&1; then
  echo "gradle must be available on PATH" >&2
  exit 1
fi

GRADLE_VERSION="$(gradle --version | awk '/^Gradle / { print $2; exit }')"
if [[ "$GRADLE_VERSION" != "9.6.0" ]]; then
  echo "Gradle 9.6.0 is required, found: ${GRADLE_VERSION:-unknown}" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

(cd "$ROOT_DIR/app" && gradle --no-daemon assembleDebug)
cp "$ROOT_DIR/app/build/outputs/apk/debug/app-debug.apk" \
  "$OUT_DIR/$APK_NAME"

echo "Built $OUT_DIR/$APK_NAME"
