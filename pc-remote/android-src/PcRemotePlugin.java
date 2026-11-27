package com.liorg.pcremote;

import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.HttpURLConnection;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Native helpers the web page can't do itself:
 *  - wake: send a Wake-on-LAN "magic packet" (UDP broadcast) to turn the PC on.
 *  - request: plain-HTTP call to the agent on the PC (no CORS, no mixed-content blocking).
 *  - appInstalled / openMoonlight / openStore / share: hand off to other apps.
 */
@CapacitorPlugin(name = "PcRemote")
public class PcRemotePlugin extends Plugin {

    @PluginMethod
    public void wake(PluginCall call) {
        final String mac = call.getString("mac", "");
        final String ip = call.getString("ip", "");
        new Thread(() -> {
            try {
                byte[] macBytes = parseMac(mac);
                byte[] packet = new byte[6 + 16 * 6];
                for (int i = 0; i < 6; i++) packet[i] = (byte) 0xFF;
                for (int i = 6; i < packet.length; i += 6) System.arraycopy(macBytes, 0, packet, i, 6);

                Set<InetAddress> targets = new LinkedHashSet<>();
                targets.add(InetAddress.getByName("255.255.255.255"));
                for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                    if (!ni.isUp() || ni.isLoopback()) continue;
                    for (InterfaceAddress ia : ni.getInterfaceAddresses()) {
                        if (ia.getAddress() instanceof Inet4Address && ia.getBroadcast() != null) targets.add(ia.getBroadcast());
                    }
                }
                String[] parts = ip.trim().split("\\.");
                if (parts.length == 4) targets.add(InetAddress.getByName(parts[0] + "." + parts[1] + "." + parts[2] + ".255"));

                int sent = 0;
                try (DatagramSocket socket = new DatagramSocket()) {
                    socket.setBroadcast(true);
                    for (int round = 0; round < 3; round++) {
                        for (InetAddress addr : targets) {
                            for (int port : new int[] {9, 7}) {
                                try {
                                    socket.send(new DatagramPacket(packet, packet.length, addr, port));
                                    sent++;
                                } catch (Exception ignored) { }
                            }
                        }
                        Thread.sleep(150);
                    }
                }
                if (sent == 0) { call.reject("No network: connect the phone to the home Wi-Fi"); return; }
                JSObject ret = new JSObject();
                ret.put("sent", sent);
                call.resolve(ret);
            } catch (IllegalArgumentException e) {
                call.reject("Bad MAC address");
            } catch (Exception e) {
                call.reject(String.valueOf(e.getMessage()));
            }
        }).start();
    }

    @PluginMethod
    public void request(PluginCall call) {
        final String url = call.getString("url", "");
        final String method = call.getString("method", "GET");
        final String token = call.getString("token", "");
        final int timeout = call.getInt("timeout", 4000);
        final String reqBody = call.getString("body", "");
        final JSObject headers = call.getObject("headers", new JSObject());
        new Thread(() -> {
            HttpURLConnection conn = null;
            try {
                URL u = new URL(url);
                // Only plain HTTP to private addresses (home network, Tailscale): this bridge can never be
                // used to reach the internet, even if the page were tricked into calling it.
                if (!"http".equals(u.getProtocol()) || !isPrivateHost(u.getHost())) { call.reject("blocked-url"); return; }
                if (!"GET".equals(method) && !"POST".equals(method)) { call.reject("blocked-method"); return; }
                conn = (HttpURLConnection) u.openConnection();
                conn.setInstanceFollowRedirects(false);
                conn.setRequestMethod(method);
                conn.setConnectTimeout(timeout);
                conn.setReadTimeout(timeout);
                conn.setUseCaches(false);
                if (token != null && !token.isEmpty()) conn.setRequestProperty("X-Token", token);
                if (headers != null) {
                    Iterator<String> keys = headers.keys();
                    while (keys.hasNext()) {
                        String k = keys.next();
                        if (k.matches("^X-[A-Za-z-]{1,30}$")) conn.setRequestProperty(k, headers.getString(k));
                    }
                }
                if ("POST".equals(method)) {
                    byte[] out = reqBody == null ? new byte[0] : reqBody.getBytes(StandardCharsets.UTF_8);
                    conn.setDoOutput(true);
                    if (out.length > 0) conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                    conn.setFixedLengthStreamingMode(out.length);
                    try (OutputStream os = conn.getOutputStream()) { os.write(out); os.flush(); }
                }
                int status = conn.getResponseCode();
                InputStream in = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
                String body = "";
                if (in != null) {
                    try (InputStream s = in) {
                        ByteArrayOutputStream buf = new ByteArrayOutputStream();
                        byte[] b = new byte[4096];
                        int n;
                        while ((n = s.read(b)) > 0) {
                            buf.write(b, 0, n);
                            if (buf.size() > 256 * 1024) throw new java.io.IOException("response-too-large");
                        }
                        body = new String(buf.toByteArray(), StandardCharsets.UTF_8);
                    }
                }
                JSObject ret = new JSObject();
                ret.put("status", status);
                ret.put("body", body);
                String sig = conn.getHeaderField("X-Sig");
                ret.put("sig", sig == null ? "" : sig);
                call.resolve(ret);
            } catch (Exception e) {
                call.reject(String.valueOf(e.getMessage()));
            } finally {
                if (conn != null) conn.disconnect();
            }
        }).start();
    }

    private static final String MOONLIGHT = "com.limelight";

    @PluginMethod
    public void appInstalled(PluginCall call) {
        String pkg = call.getString("package", MOONLIGHT);
        boolean installed;
        try {
            getContext().getPackageManager().getPackageInfo(pkg, 0);
            installed = true;
        } catch (PackageManager.NameNotFoundException e) {
            installed = false;
        }
        JSObject ret = new JSObject();
        ret.put("installed", installed);
        call.resolve(ret);
    }

    /**
     * Opens Moonlight. With a host UUID it goes straight to that PC (Moonlight's own
     * shortcut entry point); with an app name too ("Desktop") it starts that stream.
     */
    @PluginMethod
    public void openMoonlight(PluginCall call) {
        String uuid = call.getString("uuid", "");
        String name = call.getString("name", "");
        String appName = call.getString("appName", "");
        boolean direct = call.getBoolean("direct", true);
        PackageManager pm = getContext().getPackageManager();
        try {
            if (direct && (!uuid.isEmpty() || !name.isEmpty())) {
                Intent i = new Intent();
                i.setComponent(new ComponentName(MOONLIGHT, "com.limelight.ShortcutTrampoline"));
                if (!uuid.isEmpty()) i.putExtra("UUID", uuid);
                if (!name.isEmpty()) i.putExtra("Name", name);
                if (!appName.isEmpty()) i.putExtra("AppName", appName);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
                JSObject ret = new JSObject();
                ret.put("mode", "direct");
                call.resolve(ret);
                return;
            }
        } catch (Exception ignored) {
            // fall through to the app's main screen
        }
        Intent launch = pm.getLaunchIntentForPackage(MOONLIGHT);
        if (launch == null) { call.reject("not-installed"); return; }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(launch);
        JSObject ret = new JSObject();
        ret.put("mode", "main");
        call.resolve(ret);
    }

    @PluginMethod
    public void openStore(PluginCall call) {
        String pkg = call.getString("package", MOONLIGHT);
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + pkg));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        } catch (ActivityNotFoundException e) {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + pkg));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        }
        call.resolve();
    }

    @PluginMethod
    public void openUrl(PluginCall call) {
        try {
            String target = call.getString("url", "");
            if (!target.startsWith("https://")) { call.reject("blocked-url"); return; }
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(target));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject(String.valueOf(e.getMessage()));
        }
    }

    @PluginMethod
    public void share(PluginCall call) {
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_TEXT, call.getString("text", ""));
        Intent chooser = Intent.createChooser(send, call.getString("title", ""));
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(chooser);
        call.resolve();
    }

    private static boolean isPrivateHost(String host) {
        String[] p = host.split("\\.");
        if (p.length != 4) return false;
        int[] o = new int[4];
        try { for (int i = 0; i < 4; i++) { o[i] = Integer.parseInt(p[i]); if (o[i] < 0 || o[i] > 255) return false; } }
        catch (NumberFormatException e) { return false; }
        return o[0] == 10
            || (o[0] == 172 && o[1] >= 16 && o[1] <= 31)
            || (o[0] == 192 && o[1] == 168)
            || (o[0] == 100 && o[1] >= 64 && o[1] <= 127)
            || o[0] == 127;
    }

    /** Which networks the phone has right now: Wi-Fi, mobile data, VPN (e.g. Tailscale). */
    @PluginMethod
    public void netInfo(PluginCall call) {
        boolean wifi = false, cell = false, vpn = false;
        try {
            ConnectivityManager cm = (ConnectivityManager) getContext().getSystemService(android.content.Context.CONNECTIVITY_SERVICE);
            for (Network n : cm.getAllNetworks()) {
                NetworkCapabilities c = cm.getNetworkCapabilities(n);
                if (c == null) continue;
                if (c.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) vpn = true;
                else if (c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || c.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) wifi = true;
                else if (c.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) cell = true;
            }
        } catch (Exception ignored) { }
        JSObject ret = new JSObject();
        ret.put("wifi", wifi);
        ret.put("cellular", cell);
        ret.put("vpn", vpn);
        call.resolve(ret);
    }

    /** Asks the Tailscale app to connect (its documented-in-source broadcast). Rejects if Tailscale is missing. */
    @PluginMethod
    public void tailscaleConnect(PluginCall call) {
        try { getContext().getPackageManager().getPackageInfo("com.tailscale.ipn", 0); }
        catch (PackageManager.NameNotFoundException e) { call.reject("not-installed"); return; }
        Intent i = new Intent("com.tailscale.ipn.CONNECT_VPN");
        i.setClassName("com.tailscale.ipn", "com.tailscale.ipn.IPNReceiver");
        getContext().sendBroadcast(i);
        call.resolve();
    }

    @PluginMethod
    public void openApp(PluginCall call) {
        Intent launch = getContext().getPackageManager().getLaunchIntentForPackage(call.getString("package", ""));
        if (launch == null) { call.reject("not-installed"); return; }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(launch);
        call.resolve();
    }

    private static byte[] parseMac(String mac) {
        String hex = mac.replaceAll("[^0-9A-Fa-f]", "");
        if (hex.length() != 12) throw new IllegalArgumentException("mac");
        byte[] out = new byte[6];
        for (int i = 0; i < 6; i++) out[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        return out;
    }
}
