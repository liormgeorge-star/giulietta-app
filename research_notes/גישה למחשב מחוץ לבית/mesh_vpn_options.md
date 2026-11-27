# Mesh/overlay VPN options for reaching a home Windows gaming PC (Sunshine host + custom HTTP agent on :8765) from an Android phone (Moonlight + Capacitor app), as of late 2026

Research date: 2026-11-27. Note: direct page fetches of tailscale.com and developers.cloudflare.com were blocked in the research environment (DNS not allowed), so facts about those two vendors come from search-result snippets of their official pages, not full-page reads. Treat exact numbers from them as "verify on the live page".

## 1. Free tier limits and pricing (2026)

### Takeaway
All candidates have a free tier big enough for one person with a PC and a phone: Tailscale Personal (6 users, unlimited user devices), NetBird Free (5 users, 100 machines), ZeroTier Personal (about 10 devices, 1 network, after a cut from 25), Cloudflare Zero Trust Free (<50 users). Headscale and router WireGuard cost $0 in licensing but need a server/router you run yourself.

### Cited Findings
- Tailscale reworked its plans on 8 April 2026 ("pricing v4") — [Tailscale blog: pricing-v4](https://tailscale.com/blog/pricing-v4)
- Tailscale Personal (free, non-commercial): up to 6 users, unlimited user devices, up to 3 ACL groups, 50 tagged resources to start — [Tailscale pricing](https://tailscale.com/pricing?plan=personal); [Tailscale free plans doc](https://tailscale.com/docs/account/manage-plans/free-plans-discounts.md)
- Tailscale paid tiers reported as Standard US$8/user/month and Premium US$18/user/month (third-party 2026 summary; not verified on the live page) — [Activepieces 2026 Tailscale pricing](https://www.activepieces.com/blog/tailscale-pricing-plans-costs-and-features-2026); older pages (e.g. a 100-device tier) are legacy — [Tailscale legacy pricing v3](https://tailscale.com/pricing-v3)
- ZeroTier official pricing page (modified 2026-10-20) lists a free Personal tier for hobbyist/smart home/gaming use, with 10 included devices and 1 network; Essential plan reported at ~$5/month + $2 per device beyond 10 — [ZeroTier pricing](https://www.zerotier.com/pricing); [ZeroTier docs pricing](https://docs.zerotier.com/pricing); [DEV: Tailscale alternatives 2026](https://dev.to/devtoolpicks/best-tailscale-alternatives-for-indie-hackers-in-2026-27fl)
- ZeroTier free tier was reduced from 25 devices/unlimited networks to 10 devices/1 network — [Toolradar ZeroTier pricing](https://toolradar.com/tools/zerotier/pricing). CONFLICT: Toolradar and CostBench (Aug 2026) claim there is no permanent free plan — [CostBench](https://costbench.com/software/sd-wan/zerotier/free-plan/); the later official page (Oct 2026) still shows a free Personal tier.
- NetBird Free: up to 5 users and 100 machines, includes P2P encryption, access control, routing, private DNS — [NetBird docs: Plans and billing](https://docs.netbird.io/manage/settings/plans-and-billing); Team plan $5/user/month in docs vs €6/user/month on one pricing-page snapshot (conflicting) — [NetBird pricing](https://netbird.io/pricing). Self-hosting is open source; a commercial self-hosted license ("Commercial Starter") at €2,000/yr exists for businesses — [WZ-IT blog, July 2026](https://wz-it.com/en/blog/netbird-self-hosting-license-commercial-starter/)
- Cloudflare Zero Trust free plan: teams under 50 users, $0, no expiry, community support only — [Cloudflare SASE plans](https://www.cloudflare.com/plans/sase-zero-trust.md)
- Cloudflare renamed WARP Connector to "Cloudflare Mesh" (April 2026) and raised the mesh-node limit from 10 to 50 per account — [Cloudflare changelog 2026-04-14](https://developers.cloudflare.com/changelog/post/2026-04-14-cloudflare-mesh/)
- Headscale is a self-hosted open-source control server used with the official Tailscale clients (no license fee) — [Headscale docs: Android](https://juanfont.github.io/headscale/0.25.0/usage/connect/android)

### Inferences
- For a single user with 2–5 devices, every option is effectively free; the deciding factors are connectivity (direct vs relay) and ease of setup, not price.
- Headscale's real "cost" is a publicly reachable server (VPS) because the home PC behind CGNAT cannot host the control server for itself.
- WireGuard on the home router: no license cost, but requires a router that supports it AND a publicly reachable WAN IP (or IPv6) — fails outright under IPv4 CGNAT.

### Gaps
- Could not open the live Tailscale or Cloudflare pricing pages to confirm exact paid-tier prices.
- No source found for WireGuard-on-router costs/requirements specific to Israeli ISP routers (covered by the ISP researcher).

## 2. Direct P2P vs relay; CGNAT; impact on Moonlight streaming

### Takeaway
Tailscale, NetBird and ZeroTier all try direct UDP hole-punching first and fall back to a relay. Moonlight needs a direct path in practice: the official Moonlight wiki says if Tailscale stays on DERP relay, Moonlight won't stream. Under CGNAT on one side, direct usually still works; under symmetric/hard NAT on both sides (e.g. home CGNAT + cellular CGNAT), you will often get relayed. Tailscale "Peer Relays" (v1.86+) and IPv6 are the mitigations.

### Cited Findings
- Moonlight wiki (official): with Tailscale, check `tailscale ping`; "a direct connection is required. If traffic stays on a DERP relay, Moonlight won't stream between those devices." Relay servers are shared and rate-limited — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Moonlight wiki: mobile networks such as T-Mobile US may interfere with WireGuard UDP packets — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Moonlight wiki recommends ZeroTier when its Internet Hosting Tool reports Carrier-Grade NAT or double routers — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Tailscale: connections start relayed via DERP and are upgraded to direct; if that fails, a peer relay is tried; "hard NAT" (CGNAT, mobile hotspots) commonly forces DERP — [Tailscale: Connection types](https://tailscale.com/kb/1257/connection-types); [Tailscale: Poor performance between tailnet devices](https://tailscale.com/kb/1638/poor-performance-tailnet)
- Tailscale Peer Relays: your own node relays traffic; requires Tailscale 1.86+; order is Direct -> Peer Relay -> DERP; a Jan 2026 Tailscale post reported large throughput gains with a peer relay (single-user anecdote) — [Tailscale Peer Relays](https://tailscale.com/docs/features/peer-relay); [Tailscale blog Jan 2026](https://tailscale.com/blog/peer-relays-international-networks)
- `tailscale netcheck` shows NAT type and DERP latencies; `tailscale ping` output containing "relay" = DERP, "peer-relay" = peer relay, an ip:port = direct — [Tailscale: Connection types](https://tailscale.com/docs/reference/connection-types); [Tailscale DERP servers](https://tailscale.com/kb/1232/derp-servers)
- DERP relays over TCP/HTTPS and is a fallback, not a bulk transport (vendor-blog claim, not confirmed in Tailscale docs) — [SSD Nodes: Tailscale slow direct vs relayed](https://www.ssdnodes.com/learn/tailscale-slow-direct-vs-relayed)
- NetBird: prefers direct P2P; relay fallback races QUIC (UDP, lower latency) and WebSocket (TCP, works when UDP is blocked); relayed connections typically occur when both peers are behind symmetric NAT (CGNAT/cellular are usually symmetric) — [NetBird: Understanding NAT and connectivity](https://docs.netbird.io/about-netbird/understanding-nat-and-connectivity); [NetBird: Troubleshooting relayed connections](https://docs.netbird.io/help/troubleshooting-relayed-connections)
- ZeroTier: forum reports of latency rising from ~5 ms to much higher when a link falls back to relay; staff suggested IPv6 on both ends to get direct connections behind CGNAT; `zerotier-cli peers` shows DIRECT vs RELAY — [ZeroTier forum: direct behind CGNAT?](https://discuss.zerotier.com/t/is-direct-connection-possible-if-my-network-is-behind-cgnat/14416); [ZeroTier forum: Moonlight via ZeroTier](https://discuss.zerotier.com/t/moonlight-via-zerotier-help/9974); [ZeroTier forum: slow Sunshine/Moonlight](https://discuss.zerotier.com/t/slow-connection-in-sunshine-moonlight-combo/17474)
- Cloudflare: WARP->WARP/Mesh and WARP Connector carry UDP; Cloudflare re-architected cloudflared UDP proxying in July 2025 for lower session-setup latency; Cloudflare does not fragment encapsulated packets on the WARP Connector path and recommends MTU 1280 on source devices for legacy UDP apps — [Cloudflare changelog: UDP improvements (2025-07-15)](https://developers.cloudflare.com/changelog/2025-07-15-udp-improvements/); [WARP Connector tips](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/warp-connector/tips/)
- Cloudflare docs say Mesh nodes can reach each other "by their Mesh IP"; Tailscale's competitor comparison claims Cloudflare Mesh routes all traffic through Cloudflare data centers rather than true P2P (biased source, unverified) — [Cloudflare peer-to-peer (WARP-to-WARP)](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/warp-to-warp/); [Tailscale: Cloudflare Mesh vs Tailscale](https://tailscale.com/compare/cloudflare-mesh)
- Israel: anecdotal (2016–2023) reports that some Israeli ISPs (HOT, CCC) handed out non-public IPv4 and that a Bezeq technician said enabling IPv6 places IPv4 behind CGNAT; regulation reportedly requires ISPs to offer IPv6 — [linux-il 2023 thread](https://mailman.cs.huji.ac.il/pipermail/linux-il/2023-April/013618.html); [linux-il 2016](https://mailman.cs.huji.ac.il/pipermail/linux-il/2016-January/012198.html). Check: if router WAN IP is in 100.64.0.0/10 you are behind CGNAT — [NetBird NAT doc](https://docs.netbird.io/about-netbird/understanding-nat-and-connectivity)

### Inferences
- Worst case for this user: home on CGNAT + phone on Israeli cellular CGNAT = both sides hard NAT -> Tailscale DERP / NetBird relay / ZeroTier relay -> Moonlight likely unusable or poor. Mitigations in order: (a) get IPv6 working on both ends (Israeli cellular and fiber increasingly have IPv6; all three mesh tools use IPv6 for direct paths); (b) ask ISP for a public IPv4 / open a UDP port so the PC side is "easy NAT"; (c) Tailscale Peer Relay on a cheap VPS/another node with a public IP close to Israel; (d) self-hosted DERP / NetBird relay in a nearby region.
- DERP is fine for the small HTTP agent on :8765 (low bandwidth), even when it is not fine for video.
- Cloudflare is relay-by-design (via Cloudflare edge) — adds a hop and has MTU caveats; poor fit for latency-critical game streaming even though UDP technically works.
- Router WireGuard is direct by definition but only if the router has a reachable public address; no relay fallback.

### Gaps
- No independent 2025–2026 benchmark found comparing Moonlight latency/bitrate over Tailscale vs ZeroTier vs NetBird.
- Exact current DERP rate limits not confirmed from Tailscale docs.
- No Israel-specific measurement of NAT type on Partner/Cellcom/Pelephone/HOT Mobile cellular.

## 3. Moonlight/Sunshine guidance over Tailscale/ZeroTier (addresses, ports, Sunshine settings)

### Takeaway
Officially documented: add the host in Moonlight via "Add PC manually" using the Tailscale 100.x.y.z IP or MagicDNS/ts.net name (ZeroTier: "Managed IP"). Pair on the home LAN first. Sunshine treats 100.64.0.0/10 and fc00::/7 (Tailscale's IPv4/IPv6 ranges) as LAN, so the Web UI default `origin_web_ui_allowed = lan` already accepts Tailscale clients — no need to set `wan`.

### Cited Findings
- Moonlight ports: TCP 47984, 47989, 48010; UDP 47998, 47999, 48000, 48002, 48010; Windows Firewall: UDP 5353 + 47998–48010, TCP 47984, 47989, 48010 — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide). (Sunshine Web UI is TCP 47990, configured via base port; not listed in the Moonlight wiki.)
- Tailscale: each device gets a 100.x.x.x, an IPv6, and a DNS name; add host by 100.x address or ts.net hostname; pair on LAN first (required on iOS) — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- ZeroTier: install on host and every client; create network, e.g. IPv4 range 10.147.17.*, authorize each member; connect to host's Managed IP — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- Sunshine source code classifies as LAN: 192.168/16, 172.16/12, 10/8, 100.64.0.0/10, 169.254/16, fc00::/7, fe80::/64 — so Tailscale (100.64/10, fd7a:...) and ZeroTier (private ranges) peers count as LAN — [Sunshine src/network.cpp](https://raw.githubusercontent.com/LizardByte/Sunshine/master/src/network.cpp)
- Sunshine `address_family` default is IPv4 only; `both` enables IPv6 too. `origin_web_ui_allowed`: pc / lan (default) / wan (exposes Web UI to the internet; not recommended) — [Sunshine network config (Mintlify mirror of docs)](https://www.mintlify.com/LizardByte/Sunshine/configuration/network); [Sunshine security](https://mintlify.com/LizardByte/Sunshine/deployment/security)
- Sunshine's UPnP option is for port-forwarding without a VPN — not needed with a mesh VPN — [Moonlight Setup Guide wiki](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)

### Inferences
- Over a mesh VPN, keep Sunshine UPnP OFF and do not forward ports on the router; the only exposure is the tailnet.
- Use the 100.x IP rather than the MagicDNS name in Moonlight if name resolution on Android is flaky; IPv4 suffices (address_family can stay ipv4).
- No Sunshine "allowed origins" change is needed; the Web UI at https://100.x.y.z:47990 should work from the phone by default.

### Gaps
- No official Sunshine/LizardByte page specifically about Tailscale was found.
- No authoritative source on MTU tuning for Moonlight over WireGuard-based meshes (Moonlight wiki does not cover MTU). Tailscale's default tunnel MTU (1280) is general knowledge, not verified here.

## 4. Android specifics (other apps through the VPN, always-on, split tunneling, coexistence)

### Takeaway
Yes: Tailscale/ZeroTier/NetBird on Android create a system VpnService, so Moonlight and a Capacitor app making plain HTTP calls to 100.x.y.z:8765 are routed through the tunnel with no app changes. Tailscale supports per-app include/exclude split tunneling (v1.70+). Android allows only one active VPN app at a time, so these cannot run alongside a commercial VPN.

### Cited Findings
- Tailscale Android app-based split tunneling requires v1.70+; excluded apps bypass the tailnet and Tailscale DNS; Tailscale excludes some system apps by default; a mode where only chosen apps use the tailnet also exists — [Tailscale: Android app split tunneling](https://tailscale.com/kb/1444/android-app-split-tunneling)
- MDM policies IncludedPackageNames / ExcludedPackageNames for Android — [tailscale/tailscale issue #6912](https://github.com/tailscale/tailscale/issues/6912)
- Forum report: with Android "Always-on VPN" + "Block connections without VPN", Tailscale stayed disconnected until the block setting was turned off — [Tailscale forum: Android + AlwaysOn](https://forum.tailscale.com/t/android-alwayson-waning-sentiments-re-tailscale/3984)
- Android 17 Beta 3 introduces a system-level split-tunneling screen for VPN apps — [Android Authority](https://www.androidauthority.com/android-17-vpn-split-tunneling-3652497)
- Battery: a natchecker.com blog claims ZeroTier drained Android battery more and had higher jitter than Tailscale for Moonlight — promotional, no measurements — [natchecker blog](https://natchecker.com/blog/zerotier-alternative)

### Inferences
- With Tailscale, the default is not a full tunnel: only 100.64/10 (tailnet) traffic goes in the tunnel unless an exit node is selected, so normal internet traffic is unaffected and battery cost is mainly keepalives.
- Capacitor app: plain HTTP (cleartext) to 100.x requires Android cleartext permission (`android:usesCleartextTraffic` / network security config) — this is an Android/WebView constraint, not a VPN one. Consider using Tailscale HTTPS certs (ts.net name) to avoid it.
- Coexistence: because Android permits only one VPN at a time, a user who also uses e.g. a commercial VPN must turn it off; Tailscale can act as exit node to replace it.

### Gaps
- No measured 2025–2026 battery data for Tailscale/ZeroTier/NetBird on Android.
- No official Android "one VPN at a time" citation retrieved in this session (well-known Android behavior).

## 5. Windows specifics (service before login, unattended, firewall/network category)

### Takeaway
Tailscale on Windows runs a system service, but by default the connection is tied to the logged-in user; enable "Run unattended" (tray > Preferences, CLI, or `UnattendedMode` policy) so it connects at boot before login. Tailscale sets its adapter to network category Private and adds its own firewall rules; Sunshine's and the custom agent's inbound firewall rules must allow the Private profile (or Any). ZeroTier and NetBird run as Windows services by default.

### Cited Findings
- Without unattended mode the Tailscale client disconnects when the user signs out or device restarts until a user logs in; enable via tray > Preferences > Run unattended, CLI, or `UnattendedMode` system policy; Windows 10+ / Server 2016+ — [Tailscale: Run unattended](https://tailscale.com/kb/1088/run-unattended)
- Troubleshoot: ensure Tailscale service is Automatic and Running in services.msc — [Tailscale: Run unattended](https://tailscale.com/docs/how-to/run-unattended)
- Reports that CLI/script-based unattended setup was buggy; GUI path recommended — [Tailscale forum](https://forum.tailscale.com/t/any-way-to-have-a-windows-machine-connect-before-a-user-logs-in/2034); headscale doc on Windows client — [Headscale Windows client doc](https://www.github.com/juanfont/headscale/blob/main/docs/windows-client.md)
- Tailscale sets the Tailscale adapter network category to Private; an error "Windows network configuration failed" appears when it cannot — [Tailscale: set-network-category-failed](https://tailscale.com/docs/reference/messages/client/set-network-category-failed)
- Tailscale adds Windows firewall rules (e.g. "Tailscale-Process", inbound, profile Any) to accept incoming tunnels — [Tailscale blog: Windows firewall](https://tailscale.com/blog/windows-firewall); [Tailscale forum](https://forum.tailscale.com/t/strictest-set-of-possible-firewall-rules/1367)
- Third-party firewalls (e.g. Bitdefender) can block TCP over the Tailscale adapter despite allow rules — [Bitdefender community](https://community.bitdefender.com/en/discussion/105901/bitdefender-firewall-blocking-tcp-traffic-over-tailscale-virtual-adapter-despite-explicit-allow-rule)
- Check/change profile with Get-NetConnectionProfile / Set-NetConnectionProfile — [Plugable KB](https://kb.plugable.com/network-adapters/how-to-set-a-network-to-private-or-public-in-windows-10-11)
- ZeroTier has a Windows service ("ZeroTierOneService") — [ZeroTier forum](https://discuss.zerotier.com/t/unattended-start-for-windows-machines/18685)

### Inferences
- For the custom agent on 8765: create a Windows Firewall inbound rule for TCP 8765 scoped to Private profile and remote address 100.64.0.0/10 (Tailscale) — keeps it unreachable from LAN/public networks if desired. Bind the agent to 0.0.0.0 or the Tailscale IP (binding to the Tailscale IP fails if the service starts before Tailscale is up).
- Also disable key expiry for the PC node in the Tailscale admin console so it doesn't drop off after the default expiry (general Tailscale knowledge; not cited here).

### Gaps
- Could not fetch Tailscale's Windows docs directly to confirm current defaults for unattended mode in 2026 releases.
- No source found on NetBird's Windows network-category behavior.

## 6. Cloudflare Tunnel / WARP / Mesh: can it carry Moonlight's UDP stream?

### Takeaway
A public-hostname Cloudflare Tunnel (cloudflared publishing HTTP) cannot carry Moonlight; it is for HTTP(S)/TCP-ish services. The private-network path (WARP client on phone + cloudflared or Cloudflare Mesh/WARP-to-WARP on PC) does carry UDP, but all traffic goes through Cloudflare's network (relay, not direct), with MTU caveats; good for the :8765 HTTP agent, poor/unproven for game streaming.

### Cited Findings
- Cloudflare added UDP support for private networks via cloudflared + WARP (originally waitlist, 2021); previously only TCP — [Cloudflare blog: Zero Trust UDP and internal DNS](https://blog.cloudflare.com/extending-cloudflares-zero-trust-platform-to-support-udp-and-internal-dns/)
- Requires enabling Gateway proxy for TCP and UDP — [Cloudflare: private hostnames/IPs with Tunnel](https://developers.cloudflare.com/cloudflare-one/tutorials/warp-to-tunnel-internal-dns)
- cloudflared UDP proxying re-architected July 2025 for lower latency — [Cloudflare changelog](https://developers.cloudflare.com/changelog/2025-07-15-udp-improvements/)
- No fragmentation of encapsulated packets on WARP Connector path; recommend MTU 1280 on sources for UDP apps — [WARP Connector tips](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/warp-connector/tips/)
- WARP Connector renamed Cloudflare Mesh (Apr 2026); limit raised to 50 mesh nodes — [Cloudflare changelog 2026-04-14](https://developers.cloudflare.com/changelog/post/2026-04-14-cloudflare-mesh/)
- Competitor claim that Cloudflare Mesh routes all traffic through Cloudflare data centers, adding latency — [Tailscale compare page](https://tailscale.com/compare/cloudflare-mesh)

### Inferences
- Cloudflare's Israel PoPs (Tel Aviv etc.) could keep the extra hop short, but no measurements found; Moonlight's large UDP video packets + no-fragmentation rule means Moonlight's packet size may need lowering. Not recommended as primary streaming path.
- Cloudflare Tunnel with a public hostname + Access policy is a reasonable way to expose ONLY the HTTP agent (8765) without any VPN app on the phone — but the Capacitor app would then need to authenticate to Cloudflare Access (service token headers), and HTTP is via a public domain.

### Gaps
- No source found showing Moonlight working (or failing) over Cloudflare WARP/Mesh.
- Full Cloudflare docs could not be fetched to confirm whether WARP-to-WARP is ever direct P2P.

## Summary comparison (for the report writer; derived from findings above)

| Option | Free tier (2026) | Direct P2P? | Fallback relay | CGNAT both sides | Moonlight fit | Android | Windows pre-login | Effort |
|---|---|---|---|---|---|---|---|---|
| Tailscale | 6 users, unlimited user devices | Yes (WireGuard, hole punching, IPv6) | DERP (TCP, shared, rate-limited); Peer Relay v1.86+ | Often relayed; fix with IPv6 / peer relay | Best documented (Moonlight wiki); needs direct path | Per-app split tunnel v1.70+ | Run unattended | Lowest |
| ZeroTier | ~10 devices, 1 network (cut from 25) | Yes | ZeroTier roots/relay (high latency reports) | Relayed; IPv6 suggested | Documented in Moonlight wiki (recommended for CGNAT) | Works; battery/jitter complaints anecdotal | Service by default | Low |
| NetBird | 5 users, 100 machines | Yes (WireGuard) | Relay over QUIC or WebSocket | Relayed if both symmetric | No official Moonlight doc | Works (system VPN) | Service | Low-medium |
| Headscale | Free (self-host) | Same as Tailscale clients | Embedded/own DERP possible | Same as Tailscale; own DERP near Israel possible | Same as Tailscale | Official Tailscale app via "alternate server" | Same as Tailscale | High (needs VPS) |
| Router WireGuard | Free | Direct only | None | Fails on IPv4 CGNAT | Excellent if reachable | Official WireGuard app | Router-side, PC needs nothing | Medium; needs public IP |
| Cloudflare Tunnel/WARP/Mesh | <50 users free | No (via Cloudflare edge) | n/a | Works (outbound only) | Poor/unproven; MTU caveats | WARP app (only one VPN) | cloudflared service | Medium |
