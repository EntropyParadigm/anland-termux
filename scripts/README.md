# Runtime scripts

## Termux native producer

Start the daemon, launch the Android app, and run a native producer command:

```sh
scripts/anland-native-session.sh weston --backend=anland-backend.so
```

Without a command, the script keeps the daemon alive and prints the selected socket:

```sh
scripts/anland-native-session.sh
```

Default socket:

```text
$TMPDIR/anland/display_daemon.sock
```

The script exports `ANLAND_DISPLAY_SOCKET` for the producer process it launches.

## PRoot producer

Start the daemon, launch the Android app, and enter a PRoot distro with shared
`/tmp`:

```sh
scripts/anland-proot-session.sh
```

Select a distro and pass extra `proot-distro login` options:

```sh
ANLAND_PROOT_DISTRO=debian scripts/anland-proot-session.sh --user user
```

Inside the container, run the producer with:

```sh
export ANLAND_DISPLAY_SOCKET=/tmp/anland/display_daemon.sock
weston --backend=anland-backend.so
```
