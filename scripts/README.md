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
