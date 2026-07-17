#!/usr/bin/env bash
# anland-connect.sh — hand the running daemon's display connection to the
# Anland Termux Android app, via the app_process loader (Play-build path).
#
# This replaces the `pm path`-based resolution in anland-play-connect.sh, which
# fails on the Google-Play Termux build (package-visibility: it can't see the
# separately-signed display app). Instead we point app_process at a local,
# READ-ONLY copy of the APK — Android 14+ refuses to load a writable dex, so the
# 0400 mode is required, not optional.
#
# Prereq: copy the play-compat APK to ~/anland-loader.apk once.
# Run this from NATIVE Termux (app_process is an Android binary), with the
# Anland Termux app already OPEN in the foreground.
set -eu

APK="$HOME/anland-loader.apk"
: "${PREFIX:=/data/data/com.termux/files/usr}"
export ANLAND_SOCKET="${ANLAND_SOCKET:-$PREFIX/tmp/anland/display_daemon.sock}"
DAEMON_LOG="$HOME/anland-daemon.log"

if [ ! -f "$APK" ]; then
    echo "ERROR: $APK not found."
    echo "Copy the AnlandTermux play-compat APK there first, then re-run."
    exit 1
fi
if [ ! -S "$ANLAND_SOCKET" ]; then
    echo "ERROR: daemon socket $ANLAND_SOCKET not present — is the session up? (bash anland-up.sh)"
    exit 1
fi

chmod 400 "$APK"   # Android 14+ writable-dex guard

# Clear any stale loader (CmdEntryPoint is unique to our loader; safe from a file).
pkill -9 -f 'com.anland.termux.CmdEntryPoint' 2>/dev/null || true
sleep 1

echo "Make sure the Anland Termux app is OPEN in the foreground."
setsid nohup env CLASSPATH="$APK" /system/bin/app_process /system/bin \
    --nice-name=anland_loader com.anland.termux.CmdEntryPoint \
    >"$HOME/anland-loader.out" 2>&1 </dev/null &
sleep 7

if grep -q 'consumer' "$DAEMON_LOG" 2>/dev/null; then
    echo "handoff sent — the daemon accepted a consumer. Check the app for the desktop."
    tail -3 "$DAEMON_LOG"
else
    echo "loader started but no consumer yet."
    echo "If still black: confirm the app was foregrounded, then re-run this script."
    cat "$HOME/anland-loader.out" 2>/dev/null || true
fi
