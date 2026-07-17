package com.anland.termux;

import android.os.ParcelFileDescriptor;

// Binder interface exposed by CmdEntryPoint (running under the Termux uid) so the
// display app can pull the connected daemon socket fd over a Binder transaction.
// File descriptors are permitted in Binder transactions but forbidden in broadcast
// Intent extras ("Not allowed to write file descriptors here"), so the loader hands
// the app this Stub via the broadcast and the app calls getConnection() to receive
// the fd. Mirrors termux-x11's ICmdEntryInterface.getXConnection().
interface IAnlandConnection {
    ParcelFileDescriptor getConnection();
}
