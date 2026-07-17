#!/usr/bin/env bash
# anland-kwin-lite.sh  —  RUN INSIDE PROOT.
# The LIGHTWEIGHT desktop: standalone KWin (the anland-patched compositor we
# already have) with NO Plasma session — no plasmashell / plasma_session /
# ksmserver / kded / polkit / portals. Cuts the process count from ~96 to ~15,
# the whole point being to stay under Samsung's phantom-process kill limit (32).
# Launch apps from the terminal it opens (or run more `env WAYLAND_DISPLAY=... app`).
set +e
say() { printf '\n>>> %s\n' "$*"; }

# socket bridge to the native-Termux daemon
ln -sfn /data/data/com.termux/files/usr/tmp/anland /tmp/anland 2>/dev/null
[ -S /tmp/anland/display_daemon.sock ] || { say "daemon socket missing — run 'anland &' in native Termux first"; exit 1; }

# minimal runtime dir; NO screen locker
mkdir -p /run/user/0; chmod 700 /run/user/0
mkdir -p /root/.config
[ -f /root/.config/kscreenlockerrc ] || printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' > /root/.config/kscreenlockerrc

# tear down anything previous (bracket-safe patterns; this file's argv won't match)
pkill -9 -f 'kwin_waylan[d]' 2>/dev/null
pkill -9 -f 'startplasma-anlan[d]' 2>/dev/null; pkill -9 -f 'startplasma-waylan[d]' 2>/dev/null
killall -q -9 plasmashell plasma_session ksmserver kwin_wayland_wrapper Xwayland konsole 2>/dev/null
sleep 2
rm -f /run/user/0/wayland-0 /run/user/0/wayland-0.lock 2>/dev/null

# the anland / KGSL render contract (same env the full session uses)
export ANLAND=1 XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE
export MESA_LOADER_DRIVER_OVERRIDE=kgsl TURNIP_KMD=kgsl GALLIUM_DRIVER=freedreno
export FD_FORCE_KGSL=1 XWAYLAND_FORCE_KGSL_SURFACELESS=1
export ANLAND_NO_DRM_DEVICE=1 EGL_PLATFORM=surfaceless
export ANLAND_SOCKET=/tmp/anland/display_daemon.sock
export XDG_RUNTIME_DIR=/run/user/0 QT_QPA_PLATFORM=wayland
export QT_QUICK_BACKEND=software   # QtQuick GL on freedreno corrupts; CPU is safe (KWin+GL apps still HW)
unset DISPLAY PULSE_SERVER

# standalone KWin: it creates its own wayland-0 socket and connects to anland as
# the "producer". dbus-run-session gives it the session bus it needs; nothing else.
say "starting standalone KWin ..."
setsid nohup dbus-run-session -- kwin_wayland --xwayland --socket wayland-0 \
    >/root/kwin-lite.log 2>&1 </dev/null &

for _ in $(seq 1 20); do
    sleep 1
    pgrep -x kwin_wayland >/dev/null 2>&1 && break
done
KP=$(pgrep -x kwin_wayland | head -1)
[ -z "$KP" ] && { say "KWin failed — see /root/kwin-lite.log"; tail -8 /root/kwin-lite.log; exit 1; }
say "KWin up (pid $KP). Producer should be connected."

# one terminal client so there's something on screen to drive from
export WAYLAND_DISPLAY=wayland-0
TERM_BIN=$(command -v foot || command -v konsole)
setsid nohup "$TERM_BIN" >/root/term-lite.log 2>&1 </dev/null &
sleep 4

printf '\nprocesses now: %s (was ~96 for full KDE)\n' "$(ps -e --no-headers | wc -l)"
printf 'kwin=%s terminal=%s\n' "$(pgrep -c -x kwin_wayland)" "$(basename "$TERM_BIN") x $(pgrep -c -x "$(basename "$TERM_BIN")")"
say "Now in NATIVE TERMUX: open the Anland app, then run:  bash ~/anland-connect.sh"
