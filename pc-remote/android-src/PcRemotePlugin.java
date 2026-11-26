package com.liorg.pcremote;

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
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Native helpers the web page can't do itself:
 *  - wake: send a Wake-on-LAN "magic packet" (UDP broadcast) to turn the PC on.
 *  - request: plain-HTTP call to the agent on the PC (no CORS, no mixed-content blocking).
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
        new Thread(() -> {
            HttpURLConnection conn = null;
            try {
                conn = (HttpURLConnection) new URL(url).openConnection();
                conn.setRequestMethod(method);
                conn.setConnectTimeout(timeout);
                conn.setReadTimeout(timeout);
                conn.setUseCaches(false);
                if (token != null && !token.isEmpty()) conn.setRequestProperty("X-Token", token);
                if ("POST".equals(method)) {
                    conn.setDoOutput(true);
                    conn.setFixedLengthStreamingMode(0);
                    try (OutputStream os = conn.getOutputStream()) { os.flush(); }
                }
                int status = conn.getResponseCode();
                InputStream in = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
                String body = "";
                if (in != null) {
                    try (InputStream s = in) {
                        ByteArrayOutputStream buf = new ByteArrayOutputStream();
                        byte[] b = new byte[4096];
                        int n;
                        while ((n = s.read(b)) > 0) buf.write(b, 0, n);
                        body = new String(buf.toByteArray(), StandardCharsets.UTF_8);
                    }
                }
                JSObject ret = new JSObject();
                ret.put("status", status);
                ret.put("body", body);
                call.resolve(ret);
            } catch (Exception e) {
                call.reject(String.valueOf(e.getMessage()));
            } finally {
                if (conn != null) conn.disconnect();
            }
        }).start();
    }

    private static byte[] parseMac(String mac) {
        String hex = mac.replaceAll("[^0-9A-Fa-f]", "");
        if (hex.length() != 12) throw new IllegalArgumentException("mac");
        byte[] out = new byte[6];
        for (int i = 0; i < 6; i++) out[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        return out;
    }
}
