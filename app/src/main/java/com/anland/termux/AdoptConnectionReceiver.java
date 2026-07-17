package com.anland.termux;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.ParcelFileDescriptor;
import android.util.Log;

/**
 * Receives the connected daemon fd from {@link CmdEntryPoint} (which runs under
 * the Termux uid) as a ParcelFileDescriptor and routes it into the display
 * consumer.
 *
 * Trust model matches termux-x11: manifest-registered, exported, no permission.
 *
 * HARDENING TODO: because there is no permission or sender check, any app on the
 * device could send this broadcast with an fd of its choosing. That fd would be
 * adopted as the daemon control connection. A future revision should verify the
 * sender (e.g. a shared signature permission is impossible across the Play-build
 * split, so use a nonce/token handed out over the same channel, or check the
 * peer via SO_PEERCRED once adopted).
 */
public final class AdoptConnectionReceiver extends BroadcastReceiver {
    private static final String TAG = "AnlandAdoptRecv";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !CmdEntryPoint.ACTION_ADOPT_CONNECTION.equals(intent.getAction()))
            return;

        ParcelFileDescriptor pfd = intent.getParcelableExtra(CmdEntryPoint.EXTRA_CONNECTION_FD);
        if (pfd == null) {
            Log.e(TAG, "adopt broadcast with no " + CmdEntryPoint.EXTRA_CONNECTION_FD + " extra");
            return;
        }

        MainActivity inst = MainActivity.sInstance;
        if (inst != null) {
            // Already running: hand the fd straight to native (same process, so the
            // detached fd int is valid without any dup).
            inst.onAdoptConnection(pfd);
        } else {
            // Cold start: carry the PFD into MainActivity, which detaches and adopts
            // it in onCreate/onNewIntent. The system dups the fd across the launch.
            Intent launch = new Intent(context, MainActivity.class);
            launch.setAction(CmdEntryPoint.ACTION_ADOPT_CONNECTION);
            launch.putExtra(CmdEntryPoint.EXTRA_CONNECTION_FD, pfd);
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(launch);
        }
    }
}
