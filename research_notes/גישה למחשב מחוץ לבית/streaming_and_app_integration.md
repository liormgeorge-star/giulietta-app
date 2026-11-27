# Out-of-home game streaming / remote desktop (Windows PC -> Android) and companion-app integration (late 2026)

Context: Sunshine host on Windows, Moonlight client on Android, custom Capacitor companion app that talks HTTP to a small PC agent and launches Moonlight via `com.limelight.ShortcutTrampoline` with extras (UUID, Name, AppName). User in Israel (cellular CGNAT likely). Research date: 2026-11-27. Note: docs.lizardbyte.dev (Sunshine docs) could not be reached from this research session's network, so Sunshine config option details below come from secondary sources only.

## 1. Moonlight over the internet: official guidance, bitrate, data use, latency

### Takeaway
The official Moonlight Setup Guide's path for Sunshine is: pair at home first, then either enable Sunshine's built-in UPnP, port-forward manually, use IPv6, or (for CGNAT / double NAT / blocked networks) use an overlay VPN such as Tailscale or ZeroTier. Tailscale works only if the link is direct (not DERP relay). The "Moonlight Internet Hosting Tool" is the GeForce Experience-era tool; for Sunshine the guide points to Sunshine's own UPnP option instead. No official per-network bitrate numbers exist beyond "lower resolution and bitrate on mobile networks"; data use is simply bitrate x time (about 0.45 GB per hour per Mbps).

### Cited Findings
- Setup Guide recommends pairing Moonlight with the PC on the home network before streaming remotely (mandatory on iOS/tvOS). — [Moonlight Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- For Sunshine, "automatic setup" = enable the built-in UPnP option in the Network section of the Sunshine web UI. The Moonlight Internet Hosting Tool / "Moonlight Internet Streaming Tester" is described under the GeForce Experience automatic setup (i.e. legacy GFE hosts). — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Manual port forwarding: TCP 47984, 47989, 48010; UDP 47998, 47999, 48000, 48002, 48010; external and internal ports must match; test 47984/47989 on canyouseeme.org; use a DHCP reservation for the host. — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- IPv6 route: host must score 10/10 on test-ipv6.com, router must use native/DHCPv6 (not 6to4/Teredo), allow TCP 47984-48010 and UDP 47998-48010 through the IPv6 firewall, add the host by IPv6 address. — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- VPN route is recommended when the tester reports CGNAT or two chained routers, or when Moonlight is blocked on the network; options named: ZeroTier, Tailscale, NordVPN Meshnet. — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Tailscale: use `tailscale status` / `tailscale ping` to confirm a direct connection; "If it only uses a relay (DERP), Moonlight won't work between those devices"; relays are shared and rate-limited. Some mobile networks block WireGuard UDP (T-Mobile US cited as example). — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Official bandwidth guidance is thin: 5 Mbps+ upload for outside-home streaming (stated for GFE hosts); wired host + 5 GHz Wi-Fi client; lower resolution and bitrate on mobile networks. — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- FEC: a 2022 community setup guide suggests Sunshine `fec_percentage` around 5 for 60 fps, noting the default is 20 and lowering is mainly for LAN; it warns settings may have changed since (OLD, Dec 2022). — [JasSuri gist](https://gist.github.com/JasSuri/fc14ff76daa0fc788a9754ddc8c8fe3e)
- A user report says Sunshine's actual bitrate can exceed the value chosen in Moonlight (~20 Mbps selected) and suggests capping with Sunshine's `max_bitrate` config line — relevant to data caps. — [answeroverflow thread](https://www.answeroverflow.com/m/1469742467598516339) (single anecdotal report)
- A secondary 2026 guide suggests ~15 Mbps host upload for remote play and 35+ Mbps for 4K remote; not an official figure and the site has inconsistent details elsewhere. — [tech-insider.org](https://tech-insider.org/sunshine-moonlight-setup-2026/)
- General conversion rule GB = Mbps x hours / 8. — [Speedify blog](https://speedify.com/blog/better-streaming/optimize-irl-streaming-data-usage/)

### Inferences
- Computed data use (bitrate x 3600 s / 8 / 1000): 5 Mbps ≈ 2.25 GB/h; 10 Mbps ≈ 4.5 GB/h; 15 Mbps ≈ 6.75 GB/h; 20 Mbps ≈ 9 GB/h (plus small FEC/VPN overhead, and possible Sunshine overshoot). Resolution does not change data use directly; the bitrate setting does. Practical cellular starting point: 720p60 at 5-10 Mbps; 1080p60 at 10-20 Mbps on good 5G/Wi-Fi.
- In Israel, cellular CGNAT makes UPnP/port forwarding irrelevant on the phone side (the phone is only a client, so that is fine), but if the home ISP line is also behind CGNAT, port forwarding fails and a VPN (Tailscale) or IPv6 is required. IPv6 availability on Israeli fixed/mobile networks was not verified.
- Latency: no official figure found; expect home->cellular RTT to dominate (tens of ms extra vs LAN). Moonlight's on-screen stats overlay is the practical tool to measure.

### Gaps
- No official Moonlight/Sunshine numeric bitrate recommendation for cellular; no reliable 2025-2026 Reddit data found within the search budget.
- Sunshine docs (docs.lizardbyte.dev) unreachable from this session — exact defaults for `upnp`, `max_bitrate`, `fec_percentage`, `address_family`, `wan_encryption_mode` not verified here.
- Israeli carrier specifics (CGNAT, IPv6, WireGuard UDP blocking) not found.

## 2. How Moonlight Android stores and chooses host addresses (local / remote / IPv6 / manual / VPN IP)

### Takeaway
Moonlight Android keeps ONE record per host UUID with four persistent address slots (`localAddress`, `remoteAddress`, `manualAddress`, `ipv6Address`) and polls all of them in parallel, picking the first that answers in fixed priority order local -> manual -> remote -> IPv6. So: add the PC once by its Tailscale 100.x IP (or ts.net name) with "Add PC manually" — it merges into the existing paired entry (same UUID, same pinned cert), no duplicate, no re-pairing — and Moonlight will automatically use the LAN IP at home and the Tailscale IP outside. The ShortcutTrampoline launch by UUID inherits this logic, so the companion app does not need to pass an address.

### Cited Findings
- `ComputerDetails` persistent fields: `localAddress`, `remoteAddress`, `manualAddress`, `ipv6Address` (each an `AddressTuple` address+port) plus transient `activeAddress`. Loopback `127.*` local addresses are ignored. — [ComputerDetails.java](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/nvstream/http/ComputerDetails.java)
- `ComputerManagerService.parallelPollPc()` polls localAddress, manualAddress, remoteAddress, ipv6Address in parallel threads (skipping null/duplicate addresses), but waits on them in precedence order local, manual, remote, IPv6; the first in that order to return details becomes `activeAddress`; a faster lower-priority address cannot win while a higher-priority one is still pending. Responses with a different UUID are rejected. — [ComputerManagerService.java](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/computers/ComputerManagerService.java)
- Manual add (`addComputerBlocking`): if a host with the same UUID exists, its pinned `serverCert` is copied over, and the existing DB record is updated (`existingComputer.update(details)`) rather than a new one created; result is one tuple and one DB entry per UUID. — [ComputerManagerService.java](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/computers/ComputerManagerService.java)
- `manualAddress` is copied in `update()` whenever non-null (i.e. a later manual add replaces the previous manual address — there is only one manual slot). — [ComputerDetails.java](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/nvstream/http/ComputerDetails.java)
- Setup Guide for Tailscale: add the host manually using its 100.x.x.x address or ts.net hostname. — [Setup Guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- ShortcutTrampoline reads `AppView.UUID_EXTRA`, `AppView.NAME_EXTRA`, `Game.EXTRA_APP_ID`, `Game.EXTRA_APP_NAME`, `Game.EXTRA_APP_HDR`. Lookup is by UUID via the ComputerManagerService; name is fallback only if UUID is empty. App ID is resolved from AppName via the cached app list ("applist" cache) if no AppId is given. If the PC is OFFLINE and a MAC is known, it sends Wake-on-LAN up to 10 tries; otherwise shows "PC offline" / "not paired" / "PC not found" dialogs. It does not choose an address itself. — [ShortcutTrampoline.java](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/ShortcutTrampoline.java)

### Inferences
- Recommended setup: pair at home over LAN (once), then (still at home or outside with Tailscale up) "Add PC manually" with the Tailscale IP or MagicDNS name -> stored as `manualAddress` on the same entry. Using the MagicDNS name (`pc-name.tailnet-xxx.ts.net`) is more robust than the raw 100.x IP only if it resolves on the phone; the 100.x IP is stable per device in Tailscale.
- At home with Tailscale also on, `localAddress` still wins (higher priority). Outside, the local poll must fail/time out before manual is accepted, so expect a few seconds of extra delay at launch outside the home.
- Avoid adding a second manual address later (e.g. a DDNS name) — it would overwrite the Tailscale manual address. If port forwarding/UPnP is used, `remoteAddress` (learned from the host's reported external IP) acts as a third fallback.
- Because the trampoline resolves AppName against Moonlight's cached app list, the app list must have been loaded at least once (open the PC in Moonlight) for AppName-only launches to work.
- Wake-on-LAN from the trampoline only works on the LAN broadcast domain in practice; outside the home it will not wake the PC (out of scope; covered elsewhere).

### Gaps
- Exact string values of the extra constants (`"UUID"`, `"Name"`, `"AppName"`, `"AppId"`) were not re-verified from AppView.java/Game.java in this session; they match the user's working setup.
- Poll timeout values per address not extracted.

## 3. Alternatives for out-of-home play and remote desktop (2026)

### Takeaway
For games, Sunshine+Moonlight (with Tailscale under CGNAT) remains the best free option; Apollo+Artemis is an Android-only fork pair that adds auto virtual displays matching the phone's resolution but is drifting from upstream compatibility; Steam Remote Play/Steam Link works through NAT via Valve relays with no setup; Parsec Android is a supported (labelled experimental) client; NVIDIA GameStream is dead since 2023 with no NVIDIA local-streaming replacement. For desktop control, Chrome Remote Desktop (free, Google relay) is the easiest NAT-traversing option; RustDesk is free/open source (public servers or self-hosted relay); AnyDesk has a personal free tier; Microsoft RDP/Windows App cannot connect to a Windows Home host.

### Cited Findings
Comparison (by: NAT traversal without VPN / cost / Android client / notes)

| Option | Works through NAT/CGNAT without your own VPN? | Cost | Android client | Key trade-offs |
|---|---|---|---|---|
| Sunshine + Moonlight | No (needs UPnP/port-forward/IPv6, or Tailscale/ZeroTier under CGNAT) | Free/OSS | Yes | Best quality/latency; DERP relay unusable |
| Apollo + Artemis | Same as Sunshine | Free/OSS | Artemis = Android only | Virtual display, per-client permissions; may lose compat with stock Sunshine/Moonlight |
| Steam Remote Play / Steam Link | Yes (Steam Link Anywhere since 2019) | Free | Yes | Steam-centric; quality depends on connection |
| Parsec | Yes (STUN/relay; relay is paid-tier) | Free personal tier | Yes (experimental) | Hosting Windows/macOS only |
| NVIDIA GameStream | n/a | n/a | n/a | Discontinued Feb 2023 |
| Chrome Remote Desktop | Yes (Google STUN/TURN relay) | Free | Yes | Desktop-oriented, not for games |
| RustDesk | Yes via public/self-hosted relay | Free OSS; paid Server Pro | Yes | Self-host for privacy/perf |
| AnyDesk | Yes (vendor relay) | Free personal tier | Yes | Licence limits on free use |
| Windows App / RDP | No (and Home edition cannot host) | Needs Windows Pro | Yes | Not usable with Windows Home host |

- Apollo: self-hosted stream host for Artemis; built-in virtual display (with HDR) created when the stream starts and removed when the app quits; Windows-only; first paired client gets full permissions, others limited by default; clipboard sync, input-only mode. Artemis "currently supports Android only". Author states Apollo/Artemis "will no longer be compatible with OG Sunshine and OG Moonlight eventually". Repo ~11.7k stars, 331 open issues (snapshot fetched Nov 2026); latest release date not visible. — [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo)
- Artemis (Moonlight Android fork) release notes: virtual display and OTP/deep-link pairing only work with Apollo (2024 releases — OLD). — [ClassicOldSong/moonlight-android](https://github.com/ClassicOldSong/moonlight-android); [release v12.1-artemis-240903](https://newreleases.io/project/github/ClassicOldSong/moonlight-android/release/v12.1-artemis-240903)
- Parsec: Android app described as experimental; hosting on Android not supported; hosting only on Windows and macOS; Android joining supported with H.264/H.265 decode. — [Parsec: Install on Android](https://support.parsec.app/hc/en-us/articles/32381582866452-Install-Parsec-App-on-Android); [Parsec Feature Matrix](https://support.parsec.app/hc/en-us/articles/4407194154253-Feature-Matrix)
- Steam Link Anywhere (March 2019) allows streaming across the internet; performance depends on bandwidth/latency. — [Wikipedia: Steam Link](https://en.wikipedia.org/wiki/Steam_Link); [Android Authority](https://www.androidauthority.com/steam-link-anywhere-965952/); [Valve Remote Play page](https://store.steampowered.com/remoteplay). Claimed 2026 Android app versions (1.3.30 May 2026 etc.) come from tech-insider.org and are mutually inconsistent — unverified.
- NVIDIA discontinued GameStream support beginning February 2023, recommending Steam Link and GeForce NOW (cloud, not local); no NVIDIA-app local streaming replacement found. — [Digital Trends](https://www.digitaltrends.com/gaming/nvidia-kills-gamestream-shield/); [9to5Google](https://9to5google.com/2023/03/29/shield-tv-gamestream-removal/); [Wccftech](https://wccftech.com/nvidia-shield-ends-gamestream-service-recommends-steam-link-plus-geforce-now-as-replacements/)
- Windows 11 Home cannot host incoming RDP connections; registry hacks are unsupported; upgrade to Pro or use Chrome Remote Desktop; Windows App replaced the Remote Desktop client. — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/2193146/why-is-my-window-11-home-not-allowing-me-to-remote); [Microsoft Q&A 12753520](https://learn.microsoft.com/answers/a/12753520)
- Chrome Remote Desktop: free for personal use; Google account + Google signaling; direct/STUN with TURN relay fallback; lacks some features like drag-and-drop file transfer. RustDesk: OSS, free, NAT traversal claimed, self-hosted server option, paid Server Pro. AnyDesk: free personal tier. (Sources are vendor/affiliate blogs incl. RustDesk's own — treat as indicative.) — [RustDesk blog](https://rustdesk.com/blog/best-free-remote-desktop-software?lang=en); [HelpWire RustDesk vs AnyDesk](https://www.helpwire.app/blog/rustdesk-vs-anydesk/)

### Inferences
- For this user: keep Sunshine+Moonlight+Tailscale for games; add Chrome Remote Desktop or RustDesk only as a "desktop control" fallback (lower setup, works even when Tailscale is relayed). Steam Link is a zero-config fallback for Steam games when Tailscale cannot get a direct path (e.g. cellular network blocking UDP).
- Switching to Apollo/Artemis would change the package/intent target of the trampoline launch (Artemis is a different app id) — check before adopting.

### Gaps
- Parsec relay (Teams) pricing and AnyDesk 2026 free-tier limits not verified from vendor pages.
- No authoritative 2026 Steam Link Android changelog found.

## 4. Detecting home Wi-Fi vs outside on Android (to pick LAN vs VPN address)

### Takeaway
Reading the SSID requires ACCESS_FINE_LOCATION + location services on (and on Android 12+ a NetworkCallback registered with FLAG_INCLUDE_LOCATION_INFO); without it `getSSID()` returns `<unknown ssid>`. A permission-free and more robust approach is to probe reachability: race a short-timeout HTTP request to the agent's LAN IP and to its Tailscale IP, prefer LAN if it answers; optionally use NetworkCapabilities (TRANSPORT_WIFI / TRANSPORT_VPN) and LinkProperties (subnet/gateway) as hints.

### Cited Findings
- WifiInfo: location-sensitive fields require the same permissions as `WifiManager#getScanResults()`; without them `getSSID()` returns `WifiManager.UNKNOWN_SSID`, `getBSSID()` returns `02:00:00:00:00:00`, `getNetworkId()` returns -1. `getIpAddress()` deprecated in API 31 — use LinkProperties via `ConnectivityManager.getLinkProperties()` or `NetworkCallback.onLinkPropertiesChanged`. — [WifiInfo reference](https://developer.android.com/reference/android/net/wifi/WifiInfo)
- NetworkCapabilities: `TRANSPORT_VPN` "Indicates this network uses a VPN transport"; `NET_CAPABILITY_NOT_VPN` "Indicates that this network is not a VPN"; location-sensitive transport info requires the app hold ACCESS_FINE_LOCATION, location toggle on, and the callback registered with `NetworkCallback.FLAG_INCLUDE_LOCATION_INFO`; the app "will be blamed for location access" if included. — [NetworkCapabilities reference](https://developer.android.com/reference/android/net/NetworkCapabilities)

### Inferences
- Recommended logic for the companion app (no location permission): (1) if active network has TRANSPORT_WIFI and its LinkProperties contain an address in the home subnet (e.g. 192.168.1.0/24) -> try LAN IP first; (2) in parallel fire `GET http://<LAN-IP>:<port>/health` (timeout ~800 ms) and `GET http://100.x.y.z:<port>/health` (timeout ~2-3 s); use whichever succeeds, LAN preferred; cache the result per network (re-evaluate on `onAvailable/onLost/onCapabilitiesChanged`). Subnet match alone can false-positive on other networks with the same private range, so the health response should include a host ID.
- Capacitor: the core `@capacitor/network` plugin only reports wifi/cellular/none; VPN/LinkProperties checks need a small custom native plugin (or a community plugin). Pure JS `fetch` racing works without any plugin, but cleartext HTTP to IPs requires `android:usesCleartextTraffic` or a network security config.
- Moonlight itself does not need this logic (see section 2); only the agent HTTP calls do.

### Gaps
- No official Android doc text fetched specifically for ConnectivityManager.getActiveNetwork behaviour when a VPN is up (in practice the default network for apps routed through the VPN reports TRANSPORT_VPN).

## 5. Can an Android app check whether Tailscale is active or prompt to enable it?

### Takeaway
Yes, partially. The app can detect "some VPN is active" via NetworkCapabilities.TRANSPORT_VPN (it cannot reliably tell which VPN app without extra work; a successful ping to the 100.x agent is the real test). It can ask Tailscale to connect by sending an explicit broadcast `com.tailscale.ipn.CONNECT_VPN` to Tailscale's exported `IPNReceiver` (no permission required), or open the Tailscale app via its `tailscale://navigate` deep link / launch intent. These are unofficial (community-documented, present in source), not a stable public API.

### Cited Findings
- Tailscale Android `IPNReceiver` handles actions `com.tailscale.ipn.CONNECT_VPN` (StartVPNWorker), `com.tailscale.ipn.DISCONNECT_VPN` (StopVPNWorker), `com.tailscale.ipn.USE_EXIT_NODE` (extras `exitNode` string, `allowLanAccess` boolean); an integration LOGIN action exists only in DEBUG builds. — [IPNReceiver.java](https://github.com/tailscale/tailscale-android/blob/main/android/src/main/java/com/tailscale/ipn/IPNReceiver.java)
- Manifest: `<receiver android:name="IPNReceiver" android:exported="true">` with the three actions, no `android:permission`; MainActivity has a VIEW/BROWSABLE deep link `tailscale://navigate`. — [tailscale-android AndroidManifest.xml](https://github.com/tailscale/tailscale-android/blob/main/android/src/main/AndroidManifest.xml)
- Community use: Home Assistant / Tasker users send broadcasts to package `com.tailscale.ipn` with CONNECT_VPN/DISCONNECT_VPN; one report says it brings the Tailscale app up and that there is no intent to open the app in the background. — [Home Assistant community](https://community.home-assistant.io/t/automate-tailscale-connection-with-home-assistant/576826); [Tailscale forum](https://forum.tailscale.com/t/automating-android-vpn-connect-disconnect/4029)
- A PR proposing static App Shortcuts for Connect/Disconnect states existing IPNReceiver broadcast functionality is preserved (merge status not confirmed). — [tailscale-android PR 788 mirror](https://gh.r-mj.com/tailscale/tailscale-android/pull/788)

### Inferences
- Implementation: native plugin sends `Intent("com.tailscale.ipn.CONNECT_VPN").setClassName("com.tailscale.ipn", "com.tailscale.ipn.IPNReceiver")` via `sendBroadcast`; then poll the 100.x health endpoint for a few seconds. Requires the user to have logged in to Tailscale and granted Android VPN consent once; otherwise fall back to launching the Tailscale app (`tailscale://navigate` or launch intent) with a "please turn on Tailscale" message.
- Android 11+ package visibility: declare `<queries><package android:name="com.tailscale.ipn"/></queries>` to check whether Tailscale is installed / resolve its launch intent.
- Alternative needing no integration: set Tailscale as Android "Always-on VPN" so it is always up (battery/permissions trade-off).
- Because the receiver is undocumented, it may change in future Tailscale versions; code should treat failure gracefully.

### Gaps
- No official Tailscale KB page documenting these intents was found; behaviour (whether the app UI is brought to foreground) was not re-tested for 2026 builds.
