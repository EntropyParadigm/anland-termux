#!/data/data/com.termux/files/usr/bin/sh
set -eu

APP_COMPONENT="${ANLAND_APP_COMPONENT:-com.anland.termux/.MainActivity}"
TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
SOCKET_PATH="${ANLAND_DISPLAY_SOCKET:-$TMPDIR/anland/display_daemon.sock}"

if ! command -v anland >/dev/null 2>&1; then
    echo "anland command not found in PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$SOCKET_PATH")"
rm -f "$SOCKET_PATH"

anland "$SOCKET_PATH" &
ANLAND_DAEMON_PID=$!

cleanup() {
    kill "$ANLAND_DAEMON_PID" 2>/dev/null || true
    wait "$ANLAND_DAEMON_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 0.2
/system/bin/am start -n "$APP_COMPONENT" --es socket_path "$SOCKET_PATH" >/dev/null

export ANLAND_DISPLAY_SOCKET="$SOCKET_PATH"

if [ "$#" -eq 0 ]; then
    echo "Anland native session is ready."
    echo "ANLAND_DISPLAY_SOCKET=$ANLAND_DISPLAY_SOCKET"
    echo "Run a native producer in another Termux shell, or press Ctrl-C to stop."
    wait "$ANLAND_DAEMON_PID"
else
    "$@"
fi
