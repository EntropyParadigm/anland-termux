package com.anland.termux;

import android.annotation.SuppressLint;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.OutputStream;
import java.io.PrintStream;
import java.lang.reflect.Field;

/**
 * Command-line entry point, run under the TERMUX uid via {@code app_process}
 * (e.g. {@code CLASSPATH=<apk> app_process / com.anland.termux.CmdEntryPoint}).
 *
 * Rationale: the display app (com.anland.termux) cannot connect() to the
 * daemon's unix socket directly. On the Google-Play build of Termux the two
 * apps have distinct uids with distinct SELinux MLS categories, and
 * {@code mlsconstrain unix_stream_socket connectto} requires equal categories,
 * so a cross-uid connect is blocked by the kernel. Instead this process runs as
 * the Termux uid, connects to the daemon's own socket (same uid, always
 * allowed) and hands the *connected* fd to the display app over a Binder
 * broadcast as a ParcelFileDescriptor. Once the fd is adopted, read/write and
 * SCM_RIGHTS fd-passing across the two uids are permitted (both sit in the
 * untrusted_app domain at targetSdk >= 34).
 *
 * The app_process bootstrapping technique -- obtaining a system Context via
 * {@code sun.misc.Unsafe.allocateInstance(ActivityThread.class).getSystemContext()}
 * -- is adapted from termux-x11's CmdEntryPoint.java
 * (github.com/termux/termux-x11, app/src/main/java/com/termux/x11/CmdEntryPoint.java),
 * GPL-3.0, same license as this project. Unlike termux-x11 we reach the hidden
 * framework classes purely by reflection (no compileOnly hidden-API stub), so
 * this file builds against the plain public SDK. termux-x11 additionally has an
 * IActivityManager IntentSender fallback for when no Context is available; we
 * omit it here for simplicity -- the reflective system Context is reliable on
 * the modern Android versions this app targets (minSdk 30).
 */
@SuppressLint("StaticFieldLeak")
public final class CmdEntryPoint {
    private static final String TAG = "AnlandCmdEntry";

    // Broadcast contract -- MUST match the receiver and the daemon-side sender.
    static final String ACTION_ADOPT_CONNECTION = "com.anland.termux.ACTION_ADOPT_CONNECTION";
    static final String TARGET_PACKAGE = "com.anland.termux";
    static final String EXTRA_CONNECTION_FD = "connection_fd";

    // Mirrors MainActivity.DEFAULT_SOCKET_PATH. Duplicated deliberately: touching
    // MainActivity here would trigger its static initializer (System.loadLibrary),
    // which we must not do in the lightweight CLI process.
    private static final String DEFAULT_SOCKET_PATH =
        "/data/data/com.termux/files/usr/tmp/anland/display_daemon.sock";

    private static final int CONNECT_ATTEMPTS = 10;
    private static final long CONNECT_BACKOFF_MS = 500;

    private static Context ctx;

    static {
        try {
            if (Looper.getMainLooper() == null)
                Looper.prepareMainLooper();
        } catch (Exception e) {
            Log.e(TAG, "prepareMainLooper failed", e);
        }
        ctx = createContext();
    }

    public static void main(String[] args) {
        String path = null;
        if (args != null && args.length > 0 && args[0] != null && !args[0].isEmpty())
            path = args[0];
        if (path == null)
            path = System.getenv("ANLAND_SOCKET");
        if (path == null || path.isEmpty())
            path = DEFAULT_SOCKET_PATH;

        boolean abstractNs = path.startsWith("@");
        LocalSocketAddress.Namespace ns = abstractNs
            ? LocalSocketAddress.Namespace.ABSTRACT
            : LocalSocketAddress.Namespace.FILESYSTEM;
        String name = abstractNs ? path.substring(1) : path;

        LocalSocket sock = null;
        for (int attempt = 1; attempt <= CONNECT_ATTEMPTS && sock == null; attempt++) {
            LocalSocket s = new LocalSocket();
            try {
                s.connect(new LocalSocketAddress(name, ns));
                sock = s;
            } catch (Exception e) {
                try { s.close(); } catch (Exception ignore) {}
                if (attempt == CONNECT_ATTEMPTS) {
                    System.err.println("anland: could not connect to daemon socket '"
                        + path + "' after " + CONNECT_ATTEMPTS + " attempts: " + e.getMessage());
                    System.exit(1);
                }
                try { Thread.sleep(CONNECT_BACKOFF_MS); } catch (InterruptedException ignore) {}
            }
        }

        if (ctx == null) {
            System.err.println("anland: could not obtain a system Context to broadcast the connection");
            try { sock.close(); } catch (Exception ignore) {}
            System.exit(3);
        }

        try {
            // dup() gives the PFD an independent fd; the broadcast dups it again
            // across the binder into the display app, so the connection survives
            // this process exiting. Keep `sock` referenced until after the send so
            // GC does not close the underlying description early.
            ParcelFileDescriptor pfd = ParcelFileDescriptor.dup(sock.getFileDescriptor());

            Intent intent = new Intent(ACTION_ADOPT_CONNECTION);
            intent.setPackage(TARGET_PACKAGE);
            // Target the receiver explicitly. Under the Play build the two apps are
            // separately signed with distinct uids, and the sending uid lacks
            // QUERY_ALL_PACKAGES; an explicit component makes delivery reliable
            // rather than relying on package-visibility resolution of setPackage.
            intent.setComponent(new ComponentName(TARGET_PACKAGE, TARGET_PACKAGE + ".AdoptConnectionReceiver"));
            intent.putExtra(EXTRA_CONNECTION_FD, pfd);
            // FLAG_RECEIVER_FROM_SHELL: lets a stopped app receive the broadcast
            // when launched from a shell/root uid. Harmless from a normal app uid.
            if (android.os.Process.myUid() == 0 || android.os.Process.myUid() == 2000)
                intent.setFlags(0x00400000);

            // Re-broadcast a few times so a cold-starting display app still catches
            // it. Hold the socket/pfd references across all sends.
            for (int i = 0; i < 3; i++) {
                ctx.sendBroadcast(intent);
                try { Thread.sleep(500); } catch (InterruptedException ignore) {}
            }

            pfd.close();
            sock.close();
            System.out.println("anland: handed daemon connection to " + TARGET_PACKAGE);
            System.exit(0);
        } catch (Exception e) {
            System.err.println("anland: failed to hand off connection: " + e.getMessage());
            System.exit(2);
        }
    }

    /**
     * Obtain a system Context from a bare {@code app_process} process (no
     * Application, no ActivityThread.main). Instantiates ActivityThread without
     * running its constructor via sun.misc.Unsafe, then pulls the system context.
     * Reached entirely by reflection so this compiles against the public SDK.
     * Approach adapted from termux-x11's CmdEntryPoint.createContext().
     */
    private static Context createContext() {
        PrintStream err = System.err;
        try {
            Class<?> unsafeClass = Class.forName("sun.misc.Unsafe");
            Field theUnsafe = unsafeClass.getDeclaredField("theUnsafe");
            theUnsafe.setAccessible(true);
            Object unsafe = theUnsafe.get(null);

            Class<?> atClass = Class.forName("android.app.ActivityThread");
            // Silence harmless framework FileNotFound noise during context init.
            System.setErr(new PrintStream(new OutputStream() { public void write(int b) {} }));
            Object activityThread = unsafeClass
                .getMethod("allocateInstance", Class.class)
                .invoke(unsafe, atClass);
            return (Context) atClass.getMethod("getSystemContext").invoke(activityThread);
        } catch (Throwable t) {
            Log.e(TAG, "Failed to instantiate context", t);
            return null;
        } finally {
            System.setErr(err);
        }
    }

    private CmdEntryPoint() {}
}
