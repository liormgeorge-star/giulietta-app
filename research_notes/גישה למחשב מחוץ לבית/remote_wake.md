# Remotely waking a powered-off or sleeping home Windows PC from a phone outside the LAN (late 2026)

Context assumed: wired Ethernet PC, WoL already works inside the LAN (UDP broadcast magic packet, port 9, Android app), Fast Startup disabled. Research date 2026-11-27. Note: tailscale.com and computingforgeeks.com could not be fetched from this research environment (blocked by network policy), so the facts attributed to those pages come from search-result snippets only.

## 1. Why port-forwarding a magic packet through the router usually fails, when it works, and the security issues

### Takeaway
A plain port forward of UDP 7/9 to the PC's LAN IP usually works only for a few minutes after shutdown. Once the PC is off, the router's ARP entry for that IP expires and the router has nowhere to send the unicast packet. Most routers also drop forwards to the LAN broadcast address. It can work if the router keeps a static/permanent ARP entry (IP to MAC, or IP to ff:ff:ff:ff:ff:ff), but many consumer and ISP routers can't do this or lose the entry after a reboot. It's fragile, and it exposes an unauthenticated wake trigger on the WAN.

### Cited Findings
- A plain port forward doesn't work because routers discard broadcast packets arriving from the internet. — [Cisco Community RV082 thread](https://community.cisco.com/t5/routers-small-business/rv082-small-business-router-wake-on-lan-over-internet/m-p/2135448/highlight/true)
- The usual workaround is to forward UDP 9 (or 7) to a chosen internal IP and add a static ARP entry mapping that IP to the target MAC. DD-WRT's wiki documents the port-forward step. — [DD-WRT wiki: WOL](https://dd-wrt.com/wiki/index.php/WOL)
- Variant: a static ARP entry pointing an unused LAN IP at the broadcast MAC ff:ff:ff:ff:ff:ff on the LAN bridge lets one forwarded port wake any host in the subnet (anecdotal forum report). — [AnandTech forum](https://forums.anandtech.com/threads/wol-over-internet-help.257874/post-27432703)
- ARP expiry is the main failure mode. One user could wake their NAS over the internet "only 5 min. after power off. Then ARP entry is cleared and WOL not works." — [TP-Link Community: Wake on LAN over Internet](https://community.tp-link.com/en/home/forum/topic/2210)
- On a TP-Link Archer C6, ARP binding was not honored after a router restart, so WoL from the internet stopped working. — [TP-Link Community: ARP binding not working, Archer C6](https://community.tp-link.com/en/home/forum/topic/213328?page=2)
- Some consumer routers (e.g., some TP-Link ADSL models) expose no ARP-binding setting, and one Cisco small-business user concluded their model could not hold static ARP entries. — [TP-Link Community](https://community.tp-link.com/en/home/forum/topic/2210?page=2); [Cisco Community](https://community.cisco.com/t5/small-business-routers/rv082-small-business-router-wake-on-lan-over-internet/m-p/2135456)
- On pfSense, a static DHCP mapping with "ARP Table Static Entry" persists the entry. Others use boot scripts (`arp -s` via ShellCmd on pfSense, `ip neigh` on OpenWrt). — [Netgate forum](https://forum.netgate.com/post/294362); [OpenWrt forum: remote WoL via port forwarding](https://forum.openwrt.org/t/remote-wake-on-lan-via-port-forwarding/168870)
- OpenWrt users report the same "Wake on WAN" failure on stock setups. — [OpenWrt forum: Wake on WAN not working, Archer C7](https://forum.openwrt.org/t/wake-on-wan-not-working-18-06-archer-c7-v4/20375)
- Windows Server (RRAS) users likewise could not create a broadcast port forward for remote WoL. — [Microsoft Tech Community](https://techcommunity.microsoft.com/discussions/windowsserverinsiders/i-cant-create-a-broadcast-port-forward-for-remote-wol/3602767/replies/3603101)
- On an ASUS RT-AC68U, one user "tried every permutation of port forwarding... nothing I do will get the NAS to wake up". — [SNBForums: Remote WOL via RT-AC68U](https://www.snbforums.com/threads/remote-wol-via-rt-ac68u.25128/)
- Dynamic WAN IPs need DDNS on the router. TP-Link's guide pairs port forward (virtual server) and IP/MAC binding with DDNS. — [TP-Link FAQ 922: Set up WoL on modem](https://tp-link.com/ae/faq-922.html)
- A 2026 guide rates port-forwarding WoL "possible, fragile, not recommended" and recommends VPN-in-then-wake instead. — [NetBlade: Wake-on-LAN guide](https://netblade.app/learn/wake-on-lan)
- WoL from outside also needs a public IPv4 (or IPv6) on the router. AVM notes many mobile operators block incoming connections. — [AVM/FRITZ! KB: Starting network devices over the internet](https://at.fritz.com/en/apps/knowledge-base/FRITZ-Box-7490/36_Starting-network-devices-over-the-internet-Wake-on-LAN)

### Inferences
- Security: the magic packet has no authentication (it is just 6x0xFF followed by 16 repetitions of the MAC; the "SecureOn" password is rarely supported). An open UDP port that maps to a broadcast or static-ARP address lets anyone on the internet who guesses or sniffs the MAC power the PC on. It can also make the router reflect broadcast traffic into the LAN (a directed-broadcast/amplification concern), and it reveals an open port to scanners. The practical risk is mostly nuisance wakes rather than compromise, but it's a needless WAN exposure when VPN-based options exist.
- In Israel, many ISP connections today use CGNAT or DS-Lite on some fiber products, which would make inbound port forwarding impossible regardless of ARP. This is unverified for specific ISPs (see Gaps).

### Gaps
- Could not verify whether the Bezeq/HOT/Partner/Cellcom ISP routers support static ARP binding (no documentation found).
- Could not confirm which Israeli ISPs give a public IPv4 by default versus CGNAT in 2026.

## 2. Routers with built-in remote WoL (vendors and Israeli ISP routers)

### Takeaway
FRITZ!Box has the best-documented feature. It sends the magic packet itself and can auto-wake a device when it is accessed from the internet or over the FRITZ!Box VPN. ASUS (web GUI "Network Tools > Wake on LAN") and OpenWrt (luci-app-wol, etrherwake) can send WoL from the router, but you must first reach the router remotely, via its VPN server or Tailscale. The ASUS phone app's WoL appears to send the packet from the phone, so it only works on-LAN or over VPN. For routers issued by Israeli ISPs (Bezeq Be, HOT, Partner, Cellcom), no documentation of any WoL feature was found.

### Cited Findings
- **FRITZ!Box (AVM / FRITZ!):** under the network device's settings, enable "Start this computer automatically as soon as it is accessed from the internet". The device is started about 10 seconds after access over a shared port or a FRITZ!Box VPN client connection (smartphone/tablet). A "Start Computer" button tests WoL manually. Limitation: the box sends the packet only if the device was inactive for the last 15 minutes. It requires a public IPv4 or IPv6. — [FRITZ! KB 7490](https://at.fritz.com/en/apps/knowledge-base/FRITZ-Box-7490/36_Starting-network-devices-over-the-internet-Wake-on-LAN); [FRITZ! KB 7682](https://uk.fritz.com/service/knowledge-base/dok/FRITZ-Box-7682/36_Starting-network-devices-over-the-internet-Wake-on-LAN); [troubleshooting KB 1482](https://uk.fritz.com/service/knowledge-base/dok/FRITZ-Box-6820/1482_Network-device-does-not-start-automatically-when-accessed-from-the-internet/)
- **ASUS:** WoL is in the web GUI under Network Tools > Wake on LAN. A forum user found the ASUS Router app sends the WoL packet directly from the phone rather than instructing the router, "which means that it'll work only when the phone is on your home network". The workaround is to connect to the router's VPN server (OpenVPN/WireGuard) first. AiCloud reportedly lets you log in from outside and trigger WoL from the router (unverified user report). Sources are mostly older (pre-2025). — [SNBForums: Wake on WAN](https://www.snbforums.com/threads/wake-on-wan.84737/); [AnandTech: WoL with ASUS router](https://forums.anandtech.com/threads/wake-on-lan-with-asus-router.2396395); [dreamcraftdigital RT-AC68U + Synology guide](https://www.dreamcraftdigital.com/en/setup-wake-on-wan-with-the-asus-rt-ac68u-router-and-the-synology-ds216j-nas/)
- **TP-Link:** consumer guides use the port forward, IP/MAC binding and DDNS method. SafeStream business routers have a WOL page in the GUI. A 2025 community thread asks about WoL on the BE800 (Wi-Fi 7), with no native remote-WoL feature documented there. — [TP-Link FAQ 922](https://tp-link.com/ae/faq-922.html); [TP-Link FAQ 2156 SafeStream](https://www.tp-link.com/kz/support/faq/2156); [TP-Link Community: WoL in BE800](https://community.tp-link.com/en/home/forum/topic/857146)
- **OpenWrt:** install luci-app-wol (System > Software), then use Services > Wake on LAN. Hosts drop off the list once ARP clears, but you can enter a MAC manually. A MakeUseOf write-up describes reaching OpenWrt remotely via Tailscale and having the router send the packet locally. — [ibuyopenwrt guide](http://www.ibuyopenwrt.com/index_php/2-uncategorised/215-wake-on-lan-by-luci-app-wol); [MakeUseOf: wake home PC from anywhere, router](https://www.makeuseof.com/i-can-wake-up-home-pc-from-anywhere-router-makes-it-possible/); [OpenWrt forum](https://forum.openwrt.org/t/wake-on-lan-with-openwrt/32319)
- **OpenWrt add-ons:** projects add an MQTT trigger (openwrt-mqtt-wol) or shutdown support (WOL-plus). — [rvnzz/openwrt-mqtt-wol](https://github.com/rvnzz/openwrt-mqtt-wol); [leeyeel/WOL-plus](https://github.com/leeyeel/WOL-plus)
- **DD-WRT:** has a WOL page and a documented remote-WoL method (port forward plus static ARP, or scheduled WoL). — [DD-WRT wiki](https://dd-wrt.com/wiki/index.php/WOL)
- **MikroTik:** a writeup describes WoL via MikroTik (RouterOS has a `/tool wol` command). It can be triggered remotely through the router's VPN or scripts. — [sp1r4 writeup: MikroTik WOL](https://sp1r4.github.io/writeups/mikrotik-wol.html)
- **Israeli ISP routers:** searches in English and Hebrew ("הדלקת מחשב מרחוק Wake on LAN ראוטר בזק HOT", "hwzone Wake on LAN מחוץ לבית נתב") returned no Bezeq, HOT, Partner, Cellcom or 012 documentation of a WoL feature. — (no source found; see Gaps)

### Inferences
- Israeli ISP routers should be treated as having no remote WoL unless a user verifies it in the admin UI. A better path is a relay device on the LAN (section 3) or a customer-owned router behind the ISP box (FRITZ!Box, ASUS with VPN server, or OpenWrt).
- On ASUS, "remote WoL" in practice means router VPN server (or Tailscale on the router via Asuswrt-Merlin add-ons) plus WoL from the GUI or app.

### Gaps
- No documentation found for UniFi (UniFi Network has a client "Wake on LAN" action in some versions, but this was not confirmed in this research), and none for TP-Link Deco/Tether app remote-WoL in 2026.
- No information found on Bezeq Be / Be Fiber, HOT, Partner, Cellcom or Unlimited/012 routers' WoL, static ARP or VPN server capabilities. The user should check the admin page or ask on Hwzone in Hebrew.

## 3. Always-on relay device on the LAN plus Tailscale (Pi, old phone, NAS, ESP32, Home Assistant, UpSnap)

### Takeaway
This is the most reliable and recommended pattern in 2026. A small always-on device on the LAN (Raspberry Pi, NAS, Home Assistant box, or an old Android phone) is reachable over Tailscale (or another VPN). It sends the broadcast magic packet locally, which avoids ARP and broadcast forwarding issues entirely. Tailscale's own Aug 2025 blog promotes exactly this setup (UpSnap on a Raspberry Pi).

### Cited Findings
- Tailscale blog (Aug 19, 2025), "Making a Wake-on-LAN server using Tailscale, UpSnap and Raspberry Pi". It notes WoL typically only works on a local network and runs UpSnap, a self-hosted web app, on a Pi reached over Tailscale. — [Tailscale blog](https://tailscale.com/blog/wake-on-lan-tailscale-upsnap) (snippet only; page not fetchable from research env); [daily.dev summary](https://app.daily.dev/posts/making-a-wake-on-lan-server-using-tailscale-upsnap-and-raspberry-pi-kpwsxmw03)
- Earlier Tailscale blog/HackerNoon piece: "Make a dedicated wake on LAN server with Tailscale". — [HackerNoon](https://hackernoon.com/make-a-dedicated-wake-on-lan-server-with-tailscale)
- Community projects that run WoL over a tailnet: andygrundman/tailscale-wakeonlan (Docker; "wake your LAN devices from any device on your Tailscale tailnet"), a Helm chart version, and samn/wakeup-tailnet. — [Docker Hub](https://hub.docker.com/r/andygrundman/tailscale-wakeonlan); [GitHub helm](https://github.com/cl0vrfi3ld/tailscale-wakeonlan-helm); [wakeup-tailnet](https://awesome.ecosyste.ms/projects/github.com%2Fsamn%2Fwakeup-tailnet)
- Home Assistant wake_on_lan integration: send magic packets via a UI-configured button or a YAML switch; the switch's turn_off needs a separate command such as a REST or SSH shutdown. — [HA docs: Wake on LAN](https://www.home-assistant.io/integrations/wake_on_lan); [pimylifeup guide](https://pimylifeup.com/home-assistant-wake-on-lan/); [HA community](https://community.home-assistant.io/t/wth-is-wake-on-lan-not-a-button/478585)
- Synology DSM can act as the WoL target and integrates with ASUS router WoL (older guide). Synology/QNAP NAS also run Tailscale packages. — [dreamcraftdigital](https://www.dreamcraftdigital.com/en/setup-wake-on-wan-with-the-asus-rt-ac68u-router-and-the-synology-ds216j-nas/)
- A Reddit user reports that WoL works remotely when the home PC's LAN IP is advertised via a Tailscale subnet route. — [r/Tailscale via redlib](https://redlib.hackliberty.org/r/Tailscale/comments/1jublor/question_wake_on_lansoftware)
- A TrueNAS forum thread discusses Tailscale and WoL limits: broadcast does not traverse the tailnet. — [TrueNAS forums](https://forums.truenas.com/t/tailscale-and-wol/63887)
- Desomnia (an open-source power/WoL manager) has a Tailscale module. — [desomnia docs](https://desomnia.readthedocs.io/en/latest/modules/network/vpn/tailscale.html)
- Moonlight/Sunshine docs cover WoL for game-streaming hosts, a common use case. — [moonlight-docs WOL](https://github.com/ReenigneArcher/moonlight-docs/wiki/WOL-(Wake-On-LAN))

### Inferences
- Simplest builds, in rising order of cost and effort:
  1. An old Android phone left on charger at home, with Tailscale plus a WoL app, or Termux running `wakeonlan`. A tailnet SSH or webhook can trigger it, but Android battery and background limits make this less reliable.
  2. A Raspberry Pi (Zero 2 W or Pi 4/5) with Tailscale plus UpSnap or a plain `wakeonlan` command run over Tailscale SSH. Open the UpSnap web UI on the phone via its tailnet IP or MagicDNS name.
  3. An existing NAS or Home Assistant box with Tailscale. HA can also be reached via the Nabu Casa cloud, so the HA app button works anywhere without a VPN.
  4. ESP32/ESP8266 firmware that listens to MQTT, Telegram or HTTP and sends WoL. It needs no VPN, but security depends on the cloud broker or bot.
- A Tailscale subnet router alone does not forward broadcasts. Sending a unicast magic packet to the PC's IP via a subnet route hits the same ARP-expiry problem unless the subnet router itself sends the broadcast. So "run the sender on the LAN" is the robust approach.

### Gaps
- No 2026 hardware price list was confirmed in this research. Approximate costs as far as I know are Pi Zero 2 W ~US$15, Pi 4/5 ~US$45–80 board-only, ESP32 ~US$5. Israeli retail prices were not verified.
- Nabu Casa's 2026 subscription price was not verified (historically about US$6.50/month).
- UpSnap GitHub specifics (version, features) were not fetched.

## 4. Tailscale-specific wake features in 2026

### Takeaway
Tailscale has an internal, undocumented WoL capability: nodes report their wake MACs ("WoLMACs") in Hostinfo, and since v1.26 (2022) a PeerAPI function lets one tailnet node send a WoL packet to wake a peer on its LAN. In the material found, this has no supported UI or CLI. Tailscale's own public guidance (Aug 2025 blog) still recommends a dedicated LAN wake server such as UpSnap on a Pi. Tailscale on the sleeping PC itself can't help, because the PC is off.

### Cited Findings
- The Tailscale 1.26 release notes list "add a Wake-on-LAN function to PeerAPI" with no UI at the time (2022, possibly outdated). — [Tailscale 1.26 wiki](https://www.github.com/tailscale/tailscale/wiki/Tailscale-1.26)
- In source, `hostinfo/wol.go` `getWoLMACs` returns up to 10 local MACs. The `TS_WAKE_MAC` env var accepts a MAC, "false" or "auto". A commit message says it "supports waking up peer nodes on your LAN via Wake-on-LAN packets" (issue #306). — [Tailscale source mirror: hostinfo/wol.go](https://git.quad4.io/Mirrors/tailscale/src/commit/fc8b6d9c6a6c510227b21abf00bdfd24e53ab176/hostinfo/wol.go)
- Hostinfo exposes a `WoLMACs` field ("MAC address(es) to send Wake-on-LAN packets to wake this node"). — [pkg.go.dev tailcfg](https://pkg.go.dev/tailscale.com/tailcfg); [docs.rs tslocal Hostinfo](https://docs.rs/tslocal/0.2.2/tslocal/struct.Hostinfo.html)
- Tailscale's Aug 2025 blog says WoL "typically only works on a local network" and presents UpSnap on a Pi as the solution. — [Tailscale blog](https://tailscale.com/blog/wake-on-lan-tailscale-upsnap)
- The Tailscale forum thread "WOL possible through Tailscale?" (older) discusses the same limitation. — [Tailscale forum](https://forum.tailscale.com/t/wol-possible-through-tlscl/3372)
- The MakeUseOf article describes using Tailscale to reach an OpenWrt router that sends WoL. — [MakeUseOf](https://www.makeuseof.com/i-can-wake-up-home-pc-from-anywhere-router-makes-it-possible/)

### Inferences
- Practical Tailscale pattern: install Tailscale on an always-on LAN device (Pi, NAS, router, or HA) and from the phone either open a WoL web UI (UpSnap) over the tailnet or run `wakeonlan <MAC>` via Tailscale SSH (e.g., Termius on Android). Enabling that device as a subnet router then lets the phone RDP to the PC's LAN IP once it boots. Tailscale on the PC is still useful for access after it's awake.
- The PeerAPI WoL path is undocumented and should not be relied on.

### Gaps
- tailscale.com KB/changelog was not reachable from the research environment, so I couldn't confirm whether a user-facing WoL button appeared in the admin console or clients during 2025–2026. The report writer should state "no documented native WoL UI found" rather than "none exists".

## 5. Hardware-level alternatives (smart plug, IP-KVM, vPro/AMT, motherboard remote power, Wake on WLAN)

### Takeaway
A smart plug plus the BIOS option "Restore on AC Power Loss = Power On" is the cheapest WoL-independent way to power on from S5. Cut power, then restore it, and the PC boots. It's crude (an ungraceful power cycle if the PC was actually on) and depends on the plug's cloud app. An IP-KVM with ATX control (JetKVM ~US$69 + ATX board ~US$19–25; PiKVM V4 Mini ~US$275) gives a real "press the power button" plus BIOS-level console. Both work even if WoL breaks after a driver update.

### Cited Findings
- Smart plugs differ in post-outage behavior. TP-Link staff said Tapo's default is off after an outage, while D-Link plugs return to the last state. Check the plug's "power-on state" setting. — [TP-Link Community: Tapo P100 power loss](https://community.tp-link.com/en/home/forum/topic/668200); [D-Link FAQ](https://www.dlink.com/en/support/faq/aquilaproai/device-configuration/general/will-the-smart-plug-return-to-its-previous-on-off-state-after-a-power-outage)
- A server-class example of "Power Restore Policy" (always on, restore, always off) is Lenovo's SMM policy. Consumer BIOSes use names like "Restore on AC Power Loss" or "AC Back". — [Lenovo Power Restore Policy](https://pubs.lenovo.com/sd530/smm_power_restore_policy)
- JetKVM requires an ATX extension board (~US$19 from WisdPi, US$20–25 from iKoolCore) for real power control. Third-party Amazon sellers charged US$45.99–49.99 (Sept 2026) and Newegg US$79.99. The connector changed in April 2026, so check compatibility. — [WisdPi ATX board](https://wisdpi.com/products/atx-extension-board); [iKoolCore](https://www.ikoolcore.com/products/atx-extension-board-for-jetkvm); [WarpKVM: where to buy JetKVM 2026](https://warpkvm.com/blog/where-to-buy-jetkvm); [Newegg](https://www.newegg.com/p/3C6-019J-02874?item=9SIC2U5KU91760&negg_topt=0)
- PiKVM V4 Mini costs about US$275 direct (about US$310 on Amazon) and includes ATX control. NanoKVM Full also includes it. — [computingforgeeks 2026 IP-KVM roundup](https://computingforgeeks.com/best-ip-kvm-homelab/) (snippet only)
- Dell business PCs have their own "Deep Sleep Control" and Shutdown WoL setting. Newer Dell models won't WoL when Deep Sleep Control is set to S5. — [Dell KB](https://www.dell.com/support/article/us/en/04/sln307243/newer-dell-system-models-will-not-wake-on-lan-with-deep-sleep-control-set-to-s5-in-the-windows?lang=en)

### Inferences
- IP-KVMs (JetKVM, PiKVM, NanoKVM, GL.iNet Comet) are reachable via their own cloud or Tailscale. PiKVM and JetKVM have Tailscale support as far as I know, though that wasn't verified here. They're the "works even when everything else fails" option and also allow BIOS access and recovery from a hung PC.
- Intel vPro/AMT can power on remotely out of band, but only on business-class Q-chipset boards with vPro CPUs, so it rarely applies to home PCs. ASUS/MSI consumer boards have no native internet remote-power feature (as far as I know; not verified in this research).
- Wake on Wireless LAN (WoWLAN) is mostly limited to laptops and modern standby, and generally doesn't work from S5. It's irrelevant here because the PC is wired.

### Gaps
- No Intel AMT doc, PiKVM doc or JetKVM doc page was fetched. Prices for PiKVM V4 Plus, the JetKVM base unit and the Israeli availability/import of IP-KVMs were not confirmed.
- No source directly tested "smart plug + Restore on AC power loss" as a remote power button. This is common homelab practice, but no citation was found.

## 6. Reliability caveats (Windows updates, ErP/deep sleep, S3 vs S5)

### Takeaway
WoL from full shutdown (S5) is less reliable than from sleep (S3). It needs ErP/EuP disabled in BIOS so the NIC keeps standby power, the vendor NIC driver rather than the generic Microsoft one, and "Wake on Magic Packet" enabled. Windows updates or upgrades and driver updates are repeatedly reported to break WoL silently. Test after every major update, and keep a fallback such as a smart plug or KVM.

### Cited Findings
- Microsoft: "Wake-On-LAN is not supported from Classic Shutdown (S5) or Hybrid Shutdown (S4)" in its Windows 10 default-shutdown context. Fast Startup (hybrid shutdown) must be off. Many NICs/OEMs still support S5 WoL in practice. — [Microsoft Learn: Wake on LAN feature](https://learn.microsoft.com/en-US/troubleshoot/windows-client/deployment/wake-on-lan-feature)
- MSI: disable "EuP 2013"/"ErP Ready" to keep the LAN port powered in S3/S5. The generic Windows driver "does not always work properly with Wake on LAN, especially from S5". — [MSI FAQ: WOL](https://forum-en.msi.com/faq/article/wake-on-lan-wol)
- Arch wiki: with ErP enabled the Ethernet card isn't powered, and some boards support WoL only from sleep, not from power-off. — [Arch Wiki: Wake-on-LAN](https://wiki.archlinux.org/title/Wol)
- WoL works from suspend (S3) but fails from shutdown (S5) on some hardware, e.g., Lenovo M92p with e1000e. — [Manjaro forum](https://forum.manjaro.org/t/wol-works-from-suspend-s3-but-fails-from-shutdown-s5-lenovo-m92p-e1000e-headless-setup/183484)
- Intel I219-V: WoL stopped working on Windows 11 23H2 after a Windows update even though settings still showed enabled. — [Intel Community I219-V](https://community.intel.com/t5/Ethernet-Products/I219-V-Wake-On-Lan-no-longer-working/td-p/1589543)
- WoL never worked again after an in-place upgrade from Windows 10 to 11. Power-management checkboxes were greyed out after a clean Windows 11 install (fixed via registry). — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/1300554/wake-on-lan-does-not-works-on-windows-11-but-it-do); [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/4026255/wake-on-lan-does-not-function-despite-all-settings)
- A 2026 report (update 2026-01-12) describes LAN/Wi-Fi adapters failing to resume from sleep after updates. — [Microsoft Q&A answer](https://learn.microsoft.com/en-us/answers/a/12539598)
- Fixes: use the OEM/vendor NIC driver, disable Fast Startup, and check `powercfg /devicequery wake_programmable` (and `wake_armed`). — [Windows Report](https://windowsreport.com/wake-on-magic-packet-missing/); [ElevenForum](https://www.elevenforum.com/t/enable-or-disable-wake-on-lan-wol-in-windows-11.11872/post-244982)
- Intel's support article covers WoL setup and Fast Startup guidance for Intel NICs. — [Intel 000038313](https://intel.com/content/www/us/en/support/articles/000038313.html)
- A Russian Q&A answer says no fully reliable WAN WoL method exists and that sleep or hibernate is more dependable than full shutdown (forum opinion). — [Habr Q&A](https://qna.habr.com/q/1316408)

### Inferences
- Recommended hardening: after each feature update, re-check the adapter's Advanced tab (Wake on Magic Packet; disable "Energy Efficient Ethernet"/"Green Ethernet" if WoL fails; disable "Shutdown Wake-On-Lan" overrides on some Intel/Realtek drivers) and the Power Management tab. Keep Fast Startup off, since updates can re-enable it. A power outage can also leave the NIC unpowered until the PC is booted once on some boards. That last point is common lore and wasn't cited here; "Restore on AC Power Loss" mitigates it.
- Using sleep (S3) instead of shutdown improves wake reliability at the cost of a few watts.

### Gaps
- No official Microsoft statement found that Windows 11 updates reset NIC WoL settings. Evidence is user reports and driver regressions.
- I did not find a confirmed source for "Fast Startup re-enabled by updates" or for the power-outage NIC behavior.
