# anland Termux daemon

This directory vendors Anland's display daemon for Termux and builds it as the
`anland` command.

Default socket:

```text
$TMPDIR/anland/display_daemon.sock
```

If `TMPDIR` is not set, the command falls back to:

```text
/data/data/com.termux/files/usr/tmp/anland/display_daemon.sock
```

Usage:

```sh
anland
anland /custom/path/display_daemon.sock
anland --socket /custom/path/display_daemon.sock
```

Build inside Termux:

```sh
make -C termux/anland
make -C termux/anland install
```
