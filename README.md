# Anland: Termux

**English** | [中文](README_zh.md)

---

Use [Anland](https://github.com/superturtlee/anland) in Termux, including **Termux native** and **PRoot/Chroot/LXC** containers.

## Current Shape

- Based on Anland
- Android app: `app/`
  - package: `com.anland.termux`
  - label: `Anland Termux`
  - shared UID: `com.termux`
  - signed with `app/testkey_untrusted.jks`
- Termux command: `termux/anland/`
  - binary name: `anland`
  - default socket: `$TMPDIR/anland/display_daemon.sock`

## User Guide

See [Anland: Termux User Guide](docs/user-guide.md).

## Build

### Android Display App

Requirements:

```text
Android Gradle Plugin 9.2.1
Gradle 9.6.0
Android NDK 29.0.14206865
minSdk 30
compileSdk 36
```

Build script:

```sh
tools/build-app.sh
```

Build artifact:

```text
out/AnlandTermux-<version>.apk
```

### Anland Daemon

Build script:

```sh
tools/build-termux-anland.sh
```

When this is run inside Termux, the output is a Termux executable:

```text
out/anland
```

The draft Termux package recipe is located at:

```text
packages/anland/build.sh
```

Related pull request: https://github.com/lfdevs/termux-packages/pull/11
