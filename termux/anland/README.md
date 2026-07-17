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

The `ANLAND_SOCKET` environment variable overrides the default. A path given
on the command line wins over the environment variable.

A path starting with `@` names a socket in the Linux abstract namespace
(`@name` binds to a leading NUL byte followed by `name`, no trailing NUL).
Abstract sockets are not filesystem objects, so no directory is created and
nothing is unlinked. Note that on modern Android, SELinux MLS blocks
abstract-socket connections between different app uids, so `@` mode is a
same-uid fallback only. For Google-Play/F-Droid Termux builds (display app
under a different uid) use the loader flow instead: the daemon keeps its
normal filesystem socket and `scripts/anland-play-connect.sh` runs a loader
from the display APK under the Termux uid, which connects and passes the fd
to the app over Binder.

Usage:

```sh
anland
anland /custom/path/display_daemon.sock
anland --socket /custom/path/display_daemon.sock
anland --socket @anland-display
ANLAND_SOCKET=@anland-display anland
```

Build inside Termux:

```sh
make -C termux/anland
make -C termux/anland install
```
