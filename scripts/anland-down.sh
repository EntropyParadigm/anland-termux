#!/usr/bin/env bash
# anland-down.sh — cleanly tear down an anland desktop session.
#
# Run it as a FILE (e.g. `bash anland-down.sh`), never inline: that keeps the
# pkill patterns below out of the invoking shell's own argv, which is what was
# aborting ssh sessions (the shell matched its own command line and got killed).
#
# Order matters: kill the SUPERVISORS (launch script, startplasma, session
# manager) before the compositor, or they immediately respawn kwin.
#
# Usage:
#   bash anland-down.sh          # stop the desktop session + loaders
#   bash anland-down.sh --all    # also stop the anland daemon
set +e

say() { printf '%s\n' "$*"; }

# 1. Supervisors first (so nothing respawns the compositor).
for pat in 'startplasma-anland' 'startplasma-wayland' 'plasma_session' 'ksmserver' 'plasmashell'; do
    pkill -f "$pat" 2>/dev/null
done
sleep 1

# 2. Compositor + X server.
for pat in 'kwin_wayland_wrapper' 'kwin_wayland' 'Xwayland'; do
    pkill -f "$pat" 2>/dev/null
done
sleep 1

# 3. Force-kill anything that ignored SIGTERM.
for pat in 'startplasma' 'plasma_session' 'ksmserver' 'plasmashell' 'kwin_wayland' 'Xwayland'; do
    pkill -9 -f "$pat" 2>/dev/null
done

# 4. The fd-handoff loader (CmdEntryPoint is unique to it — won't match anything else).
pkill -9 -f 'com.anland.termux.CmdEntryPoint' 2>/dev/null
sleep 1

# 5. Optionally the daemon (its comm is exactly "anland"; the loader's is not).
if [ "$1" = "--all" ] || [ "$1" = "--daemon" ]; then
    killall -9 anland 2>/dev/null
    say "daemon stopped."
fi

# Report.
left=$(pgrep -af 'kwin_wayland|startplasma|plasmashell|CmdEntryPoint' 2>/dev/null | grep -v pgrep)
if [ -n "$left" ]; then
    say "teardown: still running (re-run if needed):"
    say "$left"
else
    say "teardown: clean."
fi
