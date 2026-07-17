#!/usr/bin/env bash
# anland-update-mesa.sh — RUN INSIDE PROOT (as root).
# Checks lfdevs/mesa-for-android-container for a newer Mesa build than what's
# installed and, if found, downloads + verifies + installs it. The a840 open
# driver is actively developed, so newer builds can fix the KGSL QtQuick
# corruption (→ maybe drop QT_QUICK_BACKEND=software) and improve zink stability.
#
# Safe to run anytime. Tear the desktop down first (bash /root/anland-*.sh does),
# and relaunch after. Needs curl + tar + sha256sum (all standard).
set -euo pipefail
REPO="lfdevs/mesa-for-android-container"
API="https://api.github.com/repos/$REPO/releases?per_page=15"

# --- distro suffix (this container = debian trixie) ---
suffix="debian_trixie_arm64"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}:${VERSION_CODENAME:-}" in
        debian:trixie) suffix="debian_trixie_arm64" ;;
        ubuntu:noble)  suffix="ubuntu_noble_arm64" ;;
        ubuntu:*)      suffix="ubuntu_${VERSION_CODENAME}_arm64" ;;
        fedora:*)      suffix="fedora_${VERSION_ID}_arm64" ;;
    esac
fi
echo "distro asset suffix : $suffix"

# --- currently installed version (from the libgallium filename) ---
cur=$(find /usr/lib -maxdepth 3 -name 'libgallium-*-devel.so' 2>/dev/null | head -1 | sed -E 's/.*libgallium-(.*)\.so/\1/')
echo "installed mesa      : ${cur:-none}"

# --- find newest release that ships this distro's asset (skip turnip-only tags) ---
echo "checking $REPO ..."
json=$(curl -fsSL "$API")
# pick the first release (newest) whose assets include our suffix
# require the mesa-for-android-container_ prefix so we never pick a turnip-only asset
url=$(printf '%s' "$json" | grep -oE '"browser_download_url": *"[^"]*mesa-for-android-container_[^"]*'"$suffix"'[^"]*"' | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
if [ -z "$url" ]; then echo "no matching asset found for $suffix"; exit 1; fi
fname=$(basename "$url")
newver=$(printf '%s' "$fname" | sed -E 's/mesa-for-android-container_([0-9].*)_'"${suffix%_arm64}"'.*/\1/')
echo "latest available    : $newver"

if [ -n "${cur:-}" ] && printf '%s' "$fname" | grep -q -- "$cur"; then
    echo "==> already on the latest build. nothing to do."
    exit 0
fi

# --- download + verify + install ---
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "downloading $fname ..."
curl -fSL "$url" -o "$tmp/$fname"
# checksum from the release body if present
sum=$(printf '%s' "$json" | grep -oE '[0-9a-f]{64}  '"$fname" | head -1 | cut -d' ' -f1 || true)
if [ -n "$sum" ]; then
    echo "verifying sha256 ..."
    echo "$sum  $tmp/$fname" | sha256sum -c - || { echo "CHECKSUM MISMATCH — aborting"; exit 1; }
else
    echo "(no checksum in release body — skipping verify)"
fi
echo "installing to / ..."
tar -xf "$tmp/$fname" -C /
ldconfig
echo "==> updated mesa: ${cur:-none} -> $newver"
echo "    relaunch the desktop:  bash /root/anland-kwin-zink.sh   (or -lite)"
