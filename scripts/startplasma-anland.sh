#!/usr/bin/env bash

RED='\033[31m'
GREEN='\033[32m'
NC='\033[0m'

ANLAND_HAVE_KGSL=0
ANLAND_HAVE_DRM=0

if [[ -r /dev/kgsl-3d0 ]]; then
    ANLAND_HAVE_KGSL=1
fi

if [[ -r /dev/dri/renderD128 ]]; then
    ANLAND_HAVE_DRM=1
fi

stop_plasma() {
    killall plasmashell > /dev/null 2>&1
    killall kwin_wayland > /dev/null 2>&1
    killall startplasma > /dev/null 2>&1
}

set_common_environment() {
    unset DISPLAY
    export QT_QPA_PLATFORM=wayland
    export XDG_CURRENT_DESKTOP=KDE
    export XDG_SESSION_DESKTOP=KDE
    export ANLAND=1

    # Do not let values inherited from the parent shell override detection.
    unset ANLAND_NO_DRM_DEVICE ANLAND_DRM_DEVICE EGL_PLATFORM
    unset MESA_LOADER_DRIVER_OVERRIDE TURNIP_KMD GALLIUM_DRIVER
    unset FD_FORCE_KGSL XWAYLAND_FORCE_KGSL_SURFACELESS
}

enable_kgsl() {
    export MESA_LOADER_DRIVER_OVERRIDE=kgsl
    export TURNIP_KMD=kgsl
    export GALLIUM_DRIVER=freedreno
    export FD_FORCE_KGSL=1
    export XWAYLAND_FORCE_KGSL_SURFACELESS=1
}

show_starting_message() {
    printf '%b\n' "${GREEN}Starting KDE Plasma. Please switch to the \"Anland Termux\" app.${NC}"
}

start_termux_native() {
    if [[ $ANLAND_HAVE_KGSL -eq 0 ]]; then
        printf '%b\n' "${RED}Currently, running Anland: Termux in Termux Native on non-Snapdragon processors is not supported. Please try running it in a PRoot/Chroot/LXC container.${NC}" >&2
        return 1
    fi

    mkdir -p "$TMPDIR/run"
    chown -R "$(id -un):$(id -gn)" "$TMPDIR/run"
    chmod -R 700 "$TMPDIR/run"
    mkdir -p "$TMPDIR/.X11-unix"
    chmod 1777 "$TMPDIR/.X11-unix"

    killall anland > /dev/null 2>&1
    anland > /dev/null 2>&1 &
    stop_plasma

    set_common_environment
    unset PULSE_SERVER
    export XDG_RUNTIME_DIR="$TMPDIR/run"
    # A pre-set ANLAND_SOCKET (e.g. '@anland-display' for the abstract
    # namespace, needed with Google-Play-build Termux where the filesystem
    # socket is unreachable across uids) is kept for the daemon and clients.
    export ANLAND_SOCKET="${ANLAND_SOCKET:-$TMPDIR/anland/display_daemon.sock}"
    export ANLAND_NO_DRM_DEVICE=1
    export EGL_PLATFORM=surfaceless
    enable_kgsl

    rm -f "$XDG_RUNTIME_DIR"/wayland-* > /dev/null 2>&1
    show_starting_message
    dbus-run-session startplasma-wayland > /dev/null 2>&1
}

start_container() {
    sudo chmod -R 777 /tmp/anland
    stop_plasma
    set_common_environment
    # A pre-set ANLAND_SOCKET (e.g. '@anland-display') is kept; see above.
    export ANLAND_SOCKET="${ANLAND_SOCKET:-/tmp/anland/display_daemon.sock}"

    if [[ $ANLAND_HAVE_DRM -eq 1 ]]; then
        export ANLAND_DRM_DEVICE=/dev/dri/renderD128
    else
        export ANLAND_NO_DRM_DEVICE=1
        export EGL_PLATFORM=surfaceless
    fi

    if [[ $ANLAND_HAVE_KGSL -eq 1 ]]; then
        enable_kgsl
    fi

    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    sudo mkdir -p "$XDG_RUNTIME_DIR"
    sudo chown "$(id -un):$(id -gn)" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    rm -f "$XDG_RUNTIME_DIR"/wayland-* > /dev/null 2>&1
    sudo mkdir -p /tmp/.X11-unix
    sudo chmod 1777 /tmp/.X11-unix

    show_starting_message
    if [[ $ANLAND_HAVE_DRM -eq 0 && $ANLAND_HAVE_KGSL -eq 0 ]]; then
        dbus-run-session -- bash -lc '
            kwin_wayland plasmashell > /dev/null 2>&1 &
            sleep 3
            konsole > /dev/null 2>&1
            wait
        '
    else
        dbus-run-session startplasma-wayland > /dev/null 2>&1
    fi
}

if [[ -n ${TERMUX_VERSION:-} ]]; then
    start_termux_native
else
    start_container
fi
