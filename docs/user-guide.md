# Anland: Termux User Guide

**English** | [中文](user-guide_zh.md)

---

This guide walks you through downloading, installing, and using [Anland: Termux](https://github.com/lfdevs/anland-termux).

## Prerequisites

Before installing Anland: Termux, check that your installed Termux app comes from the [official GitHub releases](https://github.com/termux/termux-app/releases) **(not F-Droid or Google Play)**. This project supports only the Termux app from the official GitHub releases. To migrate Termux to the GitHub version, refer to the official backup and restore guide: https://wiki.termux.com/wiki/Backing_up_Termux

```sh
# Run this command in Termux; it should output 'GITHUB'
echo $TERMUX_APP__APK_RELEASE
```

## Download

In the [latest release notes](https://github.com/lfdevs/anland-termux/releases/latest), focus on the “File List” section. For example:

| Item | Filename |
| :---: | --- |
| Android Display App | `AnlandTermux-5.13.0.apk` |
| Termux Daemon | `anland_5.11.0-1_aarch64.deb` |

| | KWin | XWayland |
| :---: | --- | --- |
| Termux Native | `kwin-anland_6.7.2_aarch64.deb` | `xwayland_24.1.12-2_aarch64.deb` |
| Ubuntu 26.04 LTS | `kwin_anland-5.8-4_6.6.4-0ubuntu92.zip` | `xwayland_24.1.10-91_arm64.deb` |
| Debian 13 | `kwin_anland-5.8-debian-4_6.3.6-92.zip` | `xwayland_24.1.6-91_arm64.deb` |

The Android Display App and Termux Daemon are required. Choose the KWin and XWayland versions that match your runtime environment.

For example, to run Anland: Termux in a Debian 13 PRoot container, download these four files: `AnlandTermux-5.13.0.apk`, `anland_5.11.0-1_aarch64.deb`, `kwin_anland-5.8-debian-4_6.3.6-92.zip`, and `xwayland_24.1.6-91_arm64.deb`.

## Installation

1. Install the display app on Android, such as `AnlandTermux-5.13.0.apk`.

   After installation, **long-press the app icon** to open its settings interface.

2. Install the daemon in Termux, such as `anland_5.11.0-1_aarch64.deb`.

   ```sh
   pkg reinstall ./anland_5.11.0-1_aarch64.deb
   ```

> [!TIP]
> If you plan to use Anland in a [PRoot-Distro](https://github.com/termux/proot-distro) container, you can use the system images built by this project directly. Install one as follows:
>
> ```sh
> pkg install proot-distro
> # For Debian 13:
> proot-distro install ghcr.io/lfdevs/debian:trixie-anland-plasma --name debian-anland
> # For Ubuntu 26.04 LTS:
> proot-distro install ghcr.io/lfdevs/ubuntu:resolute-anland-plasma --name ubuntu-anland
> ```
>
> To use it, run the following commands. This starts the KDE Plasma desktop. Then switch to the “Anland Termux” app on Android.
>
> ```sh
> killall anland > /dev/null 2>&1
> anland > /dev/null 2>&1 &
> # For Debian 13:
> proot-distro login debian-anland --shared-tmp -- bash -c "startplasma-anland"
> # For Ubuntu 26.04 LTS:
> proot-distro login ubuntu-anland --shared-tmp -- bash -c "startplasma-anland"
> ```

3. After installing the KDE Plasma desktop in your runtime environment, install KWin and XWayland through its package manager. **If a file is a `.zip` archive, extract it first to obtain the actual installation packages.**

   For example, in Termux Native:

   ```sh
   pkg reinstall ./kwin-anland_6.7.2_aarch64.deb ./xwayland_24.1.12-2_aarch64.deb
   ```

   Or in a Debian 13 container:

   ```sh
   sudo apt reinstall ./xwayland_24.1.6-91_arm64.deb
   unzip kwin_anland-5.8-debian-4_6.3.6-92.zip -d kwin-debs-install/
   sudo apt reinstall kwin-debs-install/*.deb
   rm -rf kwin-debs-install/
   ```

4. Install the Freedreno (KGSL) driver in your runtime environment.

   For Termux Native, follow the instructions on this page: https://github.com/lfdevs/termux-packages/releases/tag/freedreno-26.2.0-devel-20260709

   For Linux containers, follow the instructions on this page: https://github.com/lfdevs/mesa-for-android-container/releases/latest

5. Hold the KWin, XWayland, and Mesa packages to prevent them from being affected by updates.

   For example, in Termux Native:

   ```sh
   apt-mark hold xwayland mesa mesa-vulkan-icd-freedreno
   ```

   Or in Debian 13 or Ubuntu 26.04 LTS containers:

   ```sh
   sudo apt-mark hold xwayland kwin-common kwin-data kwin-wayland libkwin6 libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium mesa-vulkan-drivers
   ```

## Usage

1. Start the daemon in Termux:

   ```sh
   killall anland > /dev/null 2>&1
   anland > /dev/null 2>&1 &
   ```

2. If your runtime environment is a Linux container, bind-mount Termux’s `$TMPDIR` to `/tmp` inside the container.

   For example, add the `--shared-tmp` option when logging into a PRoot-Distro container:

   ```sh
   proot-distro login debian --shared-tmp
   ```

3. After entering the runtime environment, download and run this helper script: [startplasma-anland.sh](../scripts/startplasma-anland.sh)

   ```sh
   curl -LO https://github.com/lfdevs/anland-termux/raw/refs/heads/termux/scripts/startplasma-anland.sh
   chmod +x ./startplasma-anland.sh
   ./startplasma-anland.sh
   ```

4. Switch to the “Anland Termux” app on Android and enjoy your Wayland desktop.
