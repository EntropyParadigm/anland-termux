package com.anland.termux;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;

/**
 * Receives the {@link IAnlandConnection} Binder from {@link CmdEntryPoint} (which
 * runs under the Termux uid) and routes it into the display consumer. The fd
 * itself is never carried in the Intent -- the app pulls it from the Binder via
 * {@code IAnlandConnection.getConnection()} (fds are forbidden in broadcast
 * extras but allowed in Binder transactions).
 *
 * Trust model matches termux-x11: manifest-registered, exported, no permission.
 * A signature permission is impossible across the Play-build split (the loader is
 * signed differently and runs under the Termux uid) and there is no pre-shared
 * secret across the uid boundary, so authentication happens AFTER adoption: the
 * fd is only accepted if its peer credentials (SO_PEERCRED) name the installed
 * Termux package's uid. See MainActivity.consumePendingConnection and the JNI
 * nativeAdoptConnection implementation. A malicious app can only forge a
 * socketpair whose peer is its own uid, which fails that check.
 */
public final class AdoptConnectionReceiver extends BroadcastReceiver {
    private static final String TAG = "AnlandAdoptRecv";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !CmdEntryPoint.ACTION_ADOPT_CONNECTION.equals(intent.getAction()))
            return;

        // Null-key Bundle/binder trick, mirroring termux-x11's onReceiveConnection.
        Bundle bundle = intent.getBundleExtra(null);
        if (bundle == null)
            bundle = intent.getExtras();
        IBinder binder = bundle == null ? null : bundle.getBinder(null);
        if (binder == null) {
            Log.e(TAG, "adopt broadcast with no connection binder");
            return;
        }

        IAnlandConnection conn = IAnlandConnection.Stub.asInterface(binder);
        if (conn == null) {
            Log.e(TAG, "adopt broadcast binder did not implement IAnlandConnection");
            return;
        }

        // Stash the connection for MainActivity to pull. It calls getConnection()
        // over Binder (not in this Intent), so no fd/serialization limits apply.
        MainActivity.sPendingConnection = conn;

        MainActivity inst = MainActivity.sInstance;
        if (inst != null) {
            // Already running: consume immediately (on a worker thread).
            inst.consumePendingConnection();
        } else {
            // Cold start: launch MainActivity, which picks up the static holder in
            // onCreate. Do NOT put the binder/fd in the launch Intent -- that would
            // hit the same fd/serialization limits and Binder-in-startActivity issues.
            Intent launch = new Intent(context, MainActivity.class);
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            context.startActivity(launch);
        }
    }
}
