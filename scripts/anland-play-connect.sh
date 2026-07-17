#!/usr/bin/env bash
#
# anland-play-connect.sh -- hand the daemon socket to the Anland display app
# on Google Play / F-Droid Termux builds, where the display APK cannot share
# Termux's uid (signature mismatch, no sharedUserId).
#
# It runs a small Java loader shipped inside the display APK
# (com.anland.termux.CmdEntryPoint) under the TERMUX uid via
# /system/bin/app_process. The loader connects to the daemon's normal
# FILESYSTEM socket (same uid, so no cross-uid SELinux problem) and passes the
# connected fd to the display app over a Binder ParcelFileDescriptor broadcast
# (the termux-x11 technique).
#
# Run this from NATIVE Termux: pm and app_process are Android binaries that do
# not exist inside PRoot/Chroot containers. This is fine even when the daemon
# itself was started for a proot-distro session -- its $TMPDIR socket still
# lives under /data/data/com.termux/files/usr/tmp on the real filesystem, so
# the default path keeps working. Only if you overrode TMPDIR inside the
# container must you pass the real (outside-the-container) socket path.
#
# Usage:
#   anland-play-connect.sh [SOCKET_PATH]
#
# The optional SOCKET_PATH argument and the ANLAND_SOCKET environment variable
# are both forwarded to the loader (argument wins, then ANLAND_SOCKET, then
# the daemon default $TMPDIR/anland/display_daemon.sock).

set -eu

APP_PACKAGE=com.anland.termux

if ! command -v pm > /dev/null 2>&1 || [[ ! -x /system/bin/app_process ]]; then
    printf '%s\n' "anland-play-connect: pm/app_process not found. Run this script from native Termux, not from a PRoot/Chroot container." >&2
    exit 1
fi

apk="$(pm path "$APP_PACKAGE" 2> /dev/null | head -n1 | cut -d: -f2)"
apk="${apk%$'\r'}"

if [[ -z $apk ]]; then
    printf '%s\n' "anland-play-connect: display app '$APP_PACKAGE' is not installed. Install the Anland Termux APK first." >&2
    exit 1
fi

# exec keeps ANLAND_SOCKET (if exported) in the loader's environment; the
# optional socket-path argument is forwarded as-is via "$@".
export CLASSPATH="$apk"
exec /system/bin/app_process /system/bin \
    --nice-name=anland_loader com.anland.termux.CmdEntryPoint "$@"
