# Anland: Termux

Use [Anland](https://github.com/superturtlee/anland) in Termux, including
Termux native producers and `proot-distro --shared-tmp` containers.

## Current Shape

- Based on Anland 1.11
- Android app: `app/`
  - package: `com.anland.termux`
  - label: `Anland Termux`
  - shared UID: `com.termux`
  - signed with `app/testkey_untrusted.jks`
- Termux command: `termux/anland/`
  - binary name: `anland`
  - default socket: `$TMPDIR/anland/display_daemon.sock`
- Session helpers: `scripts/`
  - `anland-native-session.sh`
  - `anland-proot-session.sh`

## Build

Build the Android app:

```sh
tools/build-app.sh
```

Requirements:

```text
Android Gradle Plugin 9.2.1
Gradle 9.6.0
Android NDK 29.0.14206865
minSdk 30
compileSdk 36
```

Output:

```text
out/anland-termux-debug.apk
```

Build the `anland` daemon for the current system:

```sh
tools/build-termux-anland.sh
```

When this is run inside Termux, the output is a Termux executable:

```text
out/anland
```

The Termux package recipe draft lives at:

```text
packages/anland/build.sh
```

## Run With A Termux Native Producer

Install the app, install/copy the `anland` command into Termux, then run:

```sh
anland-native-session weston --backend=anland-backend.so
```

Without a producer command, keep the daemon running and use another shell:

```sh
anland-native-session
```

## Run With PRoot

```sh
ANLAND_PROOT_DISTRO=debian anland-proot-session --user user
```

Inside the container:

```sh
export ANLAND_DISPLAY_SOCKET=/tmp/anland/display_daemon.sock
weston --backend=anland-backend.so
```

The PRoot flow requires `--shared-tmp`; the helper applies it automatically.
