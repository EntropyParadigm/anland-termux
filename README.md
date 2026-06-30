# Anland: Termux

Use [Anland](https://github.com/superturtlee/anland) in Termux, including
Termux native producers and **PRoot/Chroot** containers.

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

## Usage

Please refer to the notes in the [Releases](https://github.com/lfdevs/anland-termux/releases).

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
out/AnlandTermux-<version>.apk
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
