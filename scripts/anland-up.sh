#!/usr/bin/env bash
# anland-up.sh — bring up ONE clean anland desktop session (daemon + compositor).
#
# Works in native Termux or inside a proot-distro container: it just backgrounds
# the stock startplasma-anland.sh (which does its own DRM/KGSL detection) and
# waits for the daemon to report a producer. Run teardown first if a session may
# already be running:  bash anland-down.sh
#
# Then: open the Anland Termux app, and run  bash anland-connect.sh
set +e

DAEMON_LOG="$HOME/anland-daemon.log"
SESSION_LOG="$HOME/anland-session.log"
START="$HOME/startplasma-anland.sh"
[ -x "$START" ] || START="./startplasma-anland.sh"

# --- Hard-won settings. Do not drop these. ---
#
# plasmashell (QtQuick) rendering through freedreno/KGSL either dies silently or
# paints RGB static. Software QML fixes both; KWin and normal apps keep full GPU
# acceleration, so this costs nothing you'd notice. Must be exported BEFORE the
# session starts so plasmashell inherits it.
export QT_QUICK_BACKEND=software
#
# The KDE screen locker is an unrecoverable trap in a proot container: PAM cannot
# authenticate (root has no usable password), and KWin refuses to unlock without
# it -- the session is then only recoverable by restarting it. Keep autolock off.
if [ ! -f "$HOME/.config/kscreenlockerrc" ]; then
    mkdir -p "$HOME/.config"
    printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' \
        > "$HOME/.config/kscreenlockerrc"
fi

# 1. Ensure the daemon is running (native path also (re)starts it, but starting
#    it here first makes the log deterministic and works in-container too).
if ! pgrep -x anland >/dev/null 2>&1; then
    if command -v anland >/dev/null 2>&1; then
        setsid nohup anland >"$DAEMON_LOG" 2>&1 </dev/null &
        sleep 2
    fi
fi

# 2. Launch the compositor session, detached.
setsid nohup bash "$START" >"$SESSION_LOG" 2>&1 </dev/null &
printf 'starting compositor'

# 3. Wait (up to ~40s) for the producer to connect (native Termux is slower to
#    start the compositor than an in-container session).
ok=0
for _ in $(seq 1 40); do
    sleep 1; printf '.'
    if grep -q 'producer connected' "$DAEMON_LOG" 2>/dev/null && pgrep -x kwin_wayland >/dev/null 2>&1; then
        ok=1; break
    fi
done
printf '\n'

if [ "$ok" = 1 ]; then
    echo "compositor up — producer connected."
    echo "Next: (1) open the Anland Termux app, then (2) run:  bash anland-connect.sh"
    echo
    echo "NOTE: if you restarted this session while the app was already running,"
    echo "      fully close and reopen the app first — it holds a Binder from the"
    echo "      previous loader and will otherwise ignore the new handoff."
else
    echo "compositor did NOT reach 'producer connected' in time."
    echo "Check $SESSION_LOG and $DAEMON_LOG."
fi
