#!/data/data/com.termux/files/usr/bin/sh
set -eu

APP_COMPONENT="${ANLAND_APP_COMPONENT:-com.anland.termux/.MainActivity}"
DISTRO="${ANLAND_PROOT_DISTRO:-debian}"
TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
TERMUX_SOCKET_PATH="${ANLAND_TERMUX_SOCKET:-$TMPDIR/anland/display_daemon.sock}"
PROOT_SOCKET_PATH="${ANLAND_PROOT_SOCKET:-/tmp/anland/display_daemon.sock}"

if ! command -v anland >/dev/null 2>&1; then
    echo "anland command not found in PATH" >&2
    exit 1
fi

if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro command not found in PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$TERMUX_SOCKET_PATH")"
rm -f "$TERMUX_SOCKET_PATH"

anland "$TERMUX_SOCKET_PATH" &
ANLAND_DAEMON_PID=$!

cleanup() {
    kill "$ANLAND_DAEMON_PID" 2>/dev/null || true
    wait "$ANLAND_DAEMON_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 0.2
/system/bin/am start -n "$APP_COMPONENT" --es socket_path "$TERMUX_SOCKET_PATH" >/dev/null

export ANLAND_DISPLAY_SOCKET="$PROOT_SOCKET_PATH"

echo "Anland PRoot session is ready."
echo "Termux socket: $TERMUX_SOCKET_PATH"
echo "PRoot socket:  $ANLAND_DISPLAY_SOCKET"
echo "Entering proot-distro '$DISTRO' with --shared-tmp."

proot-distro login "$DISTRO" --shared-tmp "$@"
