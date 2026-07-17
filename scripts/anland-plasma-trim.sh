#!/usr/bin/env bash
# anland-plasma-trim.sh — RUN INSIDE PROOT.
# FULL KDE Plasma (panel, launcher, widgets) trimmed + tuned to survive on
# Samsung. Verified usable for normal work on a Galaxy S26 Ultra. Caveats:
#   - needs the Samsung battery settings (Never sleeping apps, Unrestricted) for
#     the phantom-process killer to leave it alone.
#   - a GPU-torture app (e.g. cmatrix, continuous full-screen redraw) can still
#     fault the driver and collapse it. Normal apps are fine.
#   - fallback if it collapses: bash /root/anland-kwin-zink.sh (lightweight).
set +e
say() { printf '\n>>> %s\n' "$*"; }

ln -sfn /data/data/com.termux/files/usr/tmp/anland /tmp/anland 2>/dev/null
[ -S /tmp/anland/display_daemon.sock ] || { say "daemon socket missing — run 'anland &' in native Termux"; exit 1; }

# --- trim: disable heavy optional Plasma services so they never spawn ---
mkdir -p /root/.config /root/.config/autostart
printf '[Basic Settings]\nIndexing-Enabled=false\n' > /root/.config/baloofilerc      # file indexer off
for svc in org.kde.discover.notifier plasma-discover-notifier org.kde.kalendarac; do  # update notifier / PIM off
    printf '[Desktop Entry]\nHidden=true\n' > "/root/.config/autostart/${svc}.desktop"
done

# system dbus + polkit + no locker
[ -S /run/dbus/system_bus_socket ] || { mkdir -p /run/dbus; dbus-uuidgen --ensure 2>/dev/null; dbus-daemon --system --fork 2>/dev/null; }
pgrep -x polkitd >/dev/null 2>&1 || { setsid nohup /usr/lib/polkit-1/polkitd --no-debug >/root/polkitd.log 2>&1 </dev/null & }
[ -f /root/.config/kscreenlockerrc ] || printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' > /root/.config/kscreenlockerrc

# teardown previous (bracket-safe)
pkill -9 -f 'kwin_waylan[d]' 2>/dev/null; pkill -9 -f 'startplasma-waylan[d]' 2>/dev/null; pkill -9 -f 'plasma_sessio[n]' 2>/dev/null
killall -q -9 plasmashell ksmserver kwin_wayland_wrapper Xwayland konsole 2>/dev/null
sleep 2; rm -f /run/user/0/wayland-0 /run/user/0/wayland-0.lock 2>/dev/null

# anland + ZINK (clean GPU) + software QML for plasmashell's panel + vblank (no tear)
export ANLAND=1 QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE
export MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink TU_KMD=kgsl TURNIP_KMD=kgsl TU_DEBUG=sysmem
export FD_FORCE_KGSL=1 XWAYLAND_FORCE_KGSL_SURFACELESS=1 MESA_VK_WSI_PRESENT_MODE=mailbox vblank_mode=3
export ANLAND_NO_DRM_DEVICE=1 EGL_PLATFORM=surfaceless ANLAND_SOCKET=/tmp/anland/display_daemon.sock
export XDG_RUNTIME_DIR=/run/user/0 QT_QUICK_BACKEND=software   # panel on CPU (clean); KWin/effects on zink/GPU
mkdir -p /run/user/0; chmod 700 /run/user/0
unset DISPLAY PULSE_SERVER
# NOTE: keep blur OFF in ~/.config/kwinrc (blurEnabled=false) — it's the heaviest
# effect and pushes zink to DEVICE-LOST under load. Wobbly + translucency are fine.

say "starting trimmed full Plasma (zink KWin + software panel, blur off) ..."
setsid nohup dbus-run-session -- startplasma-wayland >/root/plasma-zink.log 2>&1 </dev/null &
for _ in $(seq 1 25); do sleep 1; pgrep -x kwin_wayland >/dev/null 2>&1 && break; done
[ -z "$(pgrep -x kwin_wayland)" ] && { say "KWin failed — see /root/plasma-zink.log"; exit 1; }
for _ in $(seq 1 15); do sleep 1; pgrep -x plasmashell >/dev/null 2>&1 && break; done

# kill any heavy optional services that still slipped through
for s in baloo_file baloo_file_extractor packagekitd plasma-discover DiscoverNotifier akonadi_control akonadiserver kalendarac; do killall -q "$s" 2>/dev/null; done

printf '\nprocesses: %s   kwin=%s plasmashell=%s\n' "$(ps -e --no-headers | wc -l)" "$(pgrep -c -x kwin_wayland)" "$(pgrep -c -x plasmashell)"
say "Now in NATIVE TERMUX: open the Anland app, then run:  bash ~/anland-connect.sh"
say "If it collapses under load, fall back: bash /root/anland-kwin-zink.sh"
