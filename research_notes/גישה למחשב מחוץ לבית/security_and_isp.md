# Security and network environment for reaching a home gaming PC from outside the home (Israel focus)

Research date: 2026-11-27. Several primary sources could not be fetched from this research session because their hosts are blocked by the network allowlist: docs.lizardbyte.dev, hwzone.co.il, rotter.name, htmag.co.il, pulse.internetsociety.org and media.defense.gov. Where that happened, the notes use search-result snippets or the GitHub copy of the docs, and say so.

## Q1. Sunshine's remote-access features, security settings, ports, encryption, pairing and CVEs

### Takeaway
Out of the box Sunshine is LAN-oriented. UPnP is off, the Web UI is LAN-only, and LAN traffic is unencrypted by default. 2025–2026 brought a run of serious advisories, including a CVSS 9.8 unauthenticated authentication bypass (CVE-2026-32253, May 2026) that lets any network attacker take control of the session. Exposing Sunshine's ports directly to the internet therefore depends on patching quickly, while a VPN overlay removes that dependence.

### Cited Findings
**Settings (from docs/configuration.md on GitHub, master branch)**
- `upnp`: default **disabled**. When enabled, "Sunshine will attempt to open ports for streaming over the internet." — [Sunshine configuration.md](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
- `origin_web_ui_allowed`: default **`lan`**. The values are `pc` (localhost only), `lan` (LAN devices only) and `wan` ("anyone can access the Web UI"). — [Sunshine configuration.md](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
- `origin_pin_allowed`: this option was **not present** in the fetched configuration.md (see Gaps).
- `port`: default 47989 (range 1029–65514). "Changing it offsets the other ports." — [Sunshine configuration.md](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
- `lan_encryption_mode` defaults to **0 (no encryption)**. `wan_encryption_mode` defaults to **1 (encrypt if the client supports it)**. Mode 2 makes encryption mandatory and rejects unencrypted clients. The docs warn that encryption "can reduce streaming performance". — [Sunshine configuration.md](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
- `csrf_allowed_origins` carries the caution "Only add origins you trust." The configuration page has **no explicit warning** against exposing Sunshine to the internet. — [Sunshine configuration.md](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
- The Web UI is at https://localhost:47990 and uses a **self-signed certificate**. Pairing works like this: Moonlight shows a PIN, and the user enters it in the Web UI under "PIN". — [Sunshine getting_started.md](https://github.com/LizardByte/Sunshine/blob/master/docs/getting_started.md)

**Ports (base 47989; third-party sources, which differ slightly on the UDP list)**
- TCP 47984 (HTTPS pairing/serverinfo), 47989 (HTTP), 47990 (Web UI) and 48010 (RTSP). UDP 47998–48000 and 48002/48010. — [PortForward.com](https://portforward.com/moonlight-game-streaming/); [Mintlify mirror of Sunshine network docs](https://www.mintlify.com/LizardByte/Sunshine/configuration/network)
- Protocol roles: video over RTP on UDP 47998, control over ENet on UDP 47999, audio over RTP on UDP 48000. — [Wolf "Moonlight Protocols"](https://games-on-whales.github.io/wolf/stable/protocols/index.html)
- Web port-checkers test only TCP, so they cannot verify the UDP stream ports. — [natchecker blog](https://natchecker.com/blog/moonlight-port-forwarding)

**Advisories and CVEs (GitHub advisory list, page 1, fetched 2026-11-27)**
| Advisory | CVE | Severity | Published | Note |
|---|---|---|---|---|
| GHSA-39hj-fxvw-758m: app-wide CSRF in the Web UI leads to command injection as Administrator | CVE-2025-53095 | Critical | 2025-06-30 | Fixed in 2025.628.4510 |
| GHSA-x97g-h2vp-g2c5: clickjacking in the Web UI | CVE-2025-53096 | Moderate | 2025-06-30 | Fixed in 2025.628.4510 |
| GHSA-6p7j-5v8v-w45h: unquoted service path gives local SYSTEM | CVE-2025-54081 | Moderate | 2025-09-23 | Local only |
| GHSA-ph75-mgxh-mv57: auth bypass via improper client-certificate validation | CVE-2026-32253 | **Critical, CVSS 9.8**, AV:N/PR:N/UI:N | 2026-05-21 | Fixed in v2026.516.143833 |
| GHSA-6jvv-jqr7-m6m3: disabled clients bypass revocation with a derived cert | CVE-2026-111044 (per third-party trackers, unverified) | High | 2026-09-07 | Fixed in v2026.906.222525 |
| GHSA-36ff-frg7-492f: pairing PIN can be applied to an unintended client session | — | High | 2026-09-07 | Fixed in v2026.906.222525 (assumed same batch, unverified) |
| GHSA-26q2-58j6-qmvv: out-of-bounds heap write from malformed input packets | none | High, 8.1, PR:L | 2026-09-07 | Affects 0.21.0+, fixed in v2026.906.222525. Needs a paired client |
| GHSA-6w33-pjh7-p77c: insufficient validation of Unicode input packets | — | High | 2026-09-07 | |
| GHSA-c428-87f8-rrv5: **unauthenticated** DoS via a short ENet control packet | — | Moderate | 2026-09-07 | |
| GHSA-fp6g-27w5-489j: untrusted GUI modules run with Sunshine's Linux capabilities | — | High | 2026-09-15 | Linux only |
Sources: [Advisory list](https://github.com/LizardByte/Sunshine/security/advisories); [GHSA-ph75-mgxh-mv57](https://github.com/LizardByte/Sunshine/security/advisories/GHSA-ph75-mgxh-mv57); [GHSA-26q2-58j6-qmvv](https://github.com/LizardByte/Sunshine/security/advisories/GHSA-26q2-58j6-qmvv); [SentinelOne CVE-2025-53095](https://www.sentinelone.com/vulnerability-database/cve-2025-53095/); [OpenCVE CVE-2026-111044](https://app.opencve.io/cve/CVE-2026-111044)
- CVE-2026-32253 mechanism: Sunshine treated the OpenSSL errors "unable to get local issuer", "not yet valid" and "expired" as success. Any self-signed client certificate therefore passed authentication, and the attacker reached privileged endpoints: launching and controlling a session and injecting remote input. The advisory says this "can become practical host takeover" on full-desktop deployments. — [GHSA-ph75-mgxh-mv57](https://github.com/LizardByte/Sunshine/security/advisories/GHSA-ph75-mgxh-mv57)
- The advisory list now shows the repo also as "SunshineStream/Sunshine", so the project seems to have moved or been renamed in 2026. — [Advisory list](https://github.com/LizardByte/Sunshine/security/advisories)

### Inferences
- From late 2025 until 2026-05-21, any Sunshine host whose TCP 47984 was port-forwarded could be taken over by anyone, with no pairing needed. That alone is a strong argument against direct exposure. The September 2026 batch included a pairing-PIN mix-up and an unauthenticated DoS, so the pairing and ENet surface keeps producing bugs.
- `wan_encryption_mode=1` still allows unencrypted streams with older clients. Over the internet, set it to 2. Over a VPN, the tunnel encrypts the traffic anyway.
- The CSRF and clickjacking CVEs affect the Web UI even on the LAN. Keep `origin_web_ui_allowed` at `lan` or `pc`, and never set it to `wan`.
- Leave UPnP off. It opens ports without the user deciding which ones. Behind CGNAT (see Q4) it has no effect anyway.

### Gaps
- `origin_pin_allowed`: I could not confirm this option exists or find its semantics in the current docs. It may be renamed, newer, or a misremembered name.
- I found no explicit LizardByte statement ("do not expose to internet" or "use a VPN"), because docs.lizardbyte.dev was blocked. The only such guidance seen came from third-party sites such as Twingate.
- I did not fetch the CVE IDs for the other September 2026 advisories.
- Whether Moonlight/Sunshine encrypts video by default over WAN depends on client support (mode 1). I did not confirm the current Moonlight client behaviour.

## Q2. Risks of port-forwarding remote-access/control endpoints in 2025–2026, and why plain HTTP plus a token is unsafe

### Takeaway
Remote-access services exposed to the internet are the most common way attackers get in. In Sophos IR cases, external remote services were the initial access in 65% of cases, and RDP was abused in 90% of attacks. Internet-wide counts still show hundreds of thousands to millions of RDP hosts and tens of millions of brute-force events a month. A plain-HTTP endpoint guarded by a static token adds risks that are clear from how HTTP works: the token is readable to anyone on the path and can be replayed. For an agent that can shut down the PC and pull self-updates, a stolen token means denial of service, or code execution if the update path can be influenced.

### Cited Findings
- Sophos Active Adversary Report (1H 2024, covering 2023 IR cases): RDP was abused in **90%** of attacks, the highest since the report began. External remote services were the initial access vector in **65%** of IR cases. Compromised credentials were the root cause in more than half, and 43% of victims had no MFA. The sample was 150+ IR cases. **This is older data (2023 cases).** — [Sophos press release](https://www.sophos.com/en-us/press/press-releases/2024/04/cybercriminals-abuse-remote-desktop-protocol-rdp-90-attacks-handled)
- HoneyDB honeypots logged **28,277,910 RDP events in December 2025**, down from about 32.2M in November 2025. — [Deception substack, Dec 2025](https://deception.substack.com/p/databases-under-siege-december-2025)
- Shodan exposure counts disagree. One 2026 post gives about 415K exposed RDP hosts worldwide. An EU-only 2026 study counted 416,856 in the EU, about 40% of them in Germany. Older vendor posts cite 3.5M–4.4M. — [whois-secure 2026](https://whois-secure.com/blog/rdp-alert-415k-exposed-servers-2026); [cyberleveling EU study](https://cyberleveling.com/blog/eu-internet-exposure-research-2026); [ReliaQuest](https://reliaquest.com/blog/rdp-brute-force-attacks/). These are low-reliability secondary blogs, and the counts depend on the query.
- ESET (Hebrew RDP hardening guide): attackers scan non-standard ports too, so moving RDP off 3389 is not protection. Put RDP behind a VPN or RD Gateway, use MFA and strong passwords, and restrict by IP. — [ESET IL RDP guide](https://www.eset.com/il/business/rdp-guide/); [ESET IL blog](https://www.eset.com/il/blog/business/data-and-business-protection/remote-workforce-rdp/)
- An Israel CERT alert (ALERT-CERT-IL-W-1967) stresses securing remote-access equipment (firewalls, VPN, ZTNA) as a favoured attack vector. Only a snippet was available. — [gov.il CERT-IL alert 1967](https://www.gov.il/BlobFolder/reports/alert_1967/he/ALERT-CERT-IL-W-1967.pdf)

### Inferences (no single fetched source; based on how the protocols work)
- Plain HTTP sends the token header in cleartext. Anyone on the path can read it: a public or hotel Wi-Fi operator, an attacker running an evil-twin AP, or any hop between. A captured static token can be **replayed** indefinitely. There is no nonce or timestamp, and TLS would not stop replay by whoever already holds the token. An exposed HTTP port will also be found by internet scanners within hours or days, then brute-forced or probed for bugs in the agent.
- The self-update feature is the most dangerous part. If the update source or channel can be tampered with and binaries are not signature-verified, a man-in-the-middle can push code that runs on the PC. The agent should bind only to the LAN/VPN interface, verify signed updates over HTTPS, and preferably be reachable only through the mesh VPN. Inside an authenticated, encrypted overlay such as WireGuard or Tailscale, the HTTP plus token design becomes acceptable as a second layer.

### Gaps
- I did not find a reliable 2025–2026 primary report (Microsoft Digital Defense Report, CrowdStrike, Censys, Rapid7) with fresh RDP or VNC exposure numbers. Figures attributed to Microsoft, such as "2.5B daily RDP attempts", could not be verified and are excluded.
- I found no VNC-specific 2025–2026 statistics.

## Q3. Best-practice guidance (CISA / NSA / NCSC / Israel National Cyber Directorate)

### Takeaway
US guidance (NSA, Feb 2023) says to disable remote administration from the internet and to use a secure connection such as a VPN for remote work. The Israeli INCD material found here addresses organizations' remote-access gear rather than home users. Vendor guidance in Hebrew (ESET IL) gives the same advice: never expose RDP directly, and put it behind a VPN.

### Cited Findings
- NSA "Best Practices for Securing Your Home Network" (CSI, Feb 2023): limit administration to the internal network only, and disable remote administration on the router. For telework, set up a secure connection such as a VPN. **This guidance is from 2023.** — [NSA press release](https://www.nsa.gov/Press-Room/Press-Releases-Statements/Press-Release-View/Article/3304674/nsa-releases-best-practices-for-securing-your-home-network/); [PDF](https://media.defense.gov/2023/Feb/22/2003165170/-1/-1/0/CSI_BEST_PRACTICS_FOR_SECURING_YOUR_HOME_NETWORK.PDF) (the PDF was not fetched, so the wording comes from snippets); [Malwarebytes summary](https://www.malwarebytes.com/blog/news/2023/02/secure-your-home-network-the-nsa-way)
- Canadian Cyber Centre (ITSAP.10.016): a VPN keeps communications private over untrusted networks. — [cyber.gc.ca](https://cyber.gc.ca/en/guidance/telework-security-issues-itsap10016)
- INCD/CERT-IL: an alert stresses hardening VPN, firewall and ZTNA equipment as a common attack vector. — [CERT-IL alert 1967](https://www.gov.il/BlobFolder/reports/alert_1967/he/ALERT-CERT-IL-W-1967.pdf)

### Inferences
- The consistent advice across bodies is: do not expose remote-access or admin services; use an encrypted, authenticated tunnel; patch promptly; use MFA. A mesh VPN fits this for a home PC.

### Gaps
- I did not find a home-user INCD document (מערך הסייבר הלאומי) on remote access to personal computers. I also did not retrieve the UK NCSC or CISA home-specific pages in this session.

## Q4. Israeli ISP environment in 2026: CGNAT, public IPv4, IPv6, cellular

### Takeaway
Israeli forum reports, mostly from 2022–2024, sort ISPs into three groups. Partner, Cellcom and Bezeq International give a real public IPv4 by default. Bezeq fiber (Be/BeFiber) puts customers behind CGNAT by default, and the way out is a paid static IP, reported at about ₪15/month. HOT is inconsistent and depends on the infrastructure. Smaller ISPs such as CCC and Gilat Telecom use CGNAT unless the customer pays. Israel's IPv6 access is about 53% (ISOC Pulse, 2026). With CGNAT on either end, especially mobile data, port forwarding is impossible, and peer-to-peer VPNs may fall back to relays.

### Cited Findings
- Forum consensus (HT Magazine): Cellcom, Partner and Bezeq International do not use CGNAT and give all customers a real external IP. Bezeq International reportedly no longer takes new private customers. At Partner, a non-NAT address costs nothing extra and only a **static** IP is charged (post dated 2023). — [HT Magazine "מצב ה-cgNAT בספקיות שונות"](https://htmag.co.il/phpbb/viewtopic.php?t=367248); [HT Magazine, fiber IP thread](https://htmag.co.il/phpbb/viewtopic.php?t=370636). Only search snippets were seen; the host was blocked.
- Bezeq fiber: NAT by default, and the only way to a real IP is a paid static IP; one user wrote that there is "no way" out of NAT otherwise. — [HT Magazine](https://htmag.co.il/phpbb/viewtopic.php?t=367248); [FXP "איך לצאת מהNAT של בזק סיבים"](https://www.fxp.co.il/showthread.php?t=21457368). On HWzone, Bezeq reportedly asks **₪15** to leave CGNAT (old post, price unverified). — [HWzone thread](https://hwzone.co.il/community/topic/607217-%D7%9B%D7%AA%D7%95%D7%91%D7%AA-ip-%D7%A6%D7%99%D7%91%D7%95%D7%A8%D7%99%D7%AA/). On Rotter, a BeFiber user behind NAT was advised to use IPv6 or switch to Bezeq International, Cellcom or Partner. — [Rotter thread](https://rotter.name/nor/hard/26836.shtml)
- HOT: reports conflict. One says HOT gives an external IP to anyone who asks. Another says this is not always possible and depends on the infrastructure (copper/cable versus IBC fiber). — [HT Magazine](https://htmag.co.il/phpbb/viewtopic.php?t=367248)
- Others: Cellcom over Bezeq DSL gives an external IP. CCC over Bezeq DSL uses CGNAT unless the customer pays for a static IP. — [HWzone thread](https://hwzone.co.il/community/topic/607217-%D7%9B%D7%AA%D7%95%D7%91%D7%AA-ip-%D7%A6%D7%99%D7%91%D7%95%D7%A8%D7%99%D7%AA/). Gilat Telecom provides "NAT only". — [HT Magazine Gilat thread](https://htmag.co.il/phpbb/viewtopic.php?t=391793)
- Market structure: Bezeq runs DSL and FTTH (GPON). IBC/Unlimited and Partner run FTTH, with Partner using point-to-point and DHCP/PPPoE. HOT runs cable and sells FTTH over IBC. Many ISPs resell over Bezeq and HOT infrastructure. — [Wikipedia: Internet in Israel](https://en.wikipedia.org/wiki/Internet_in_Israel); [yuvadm/ftth-il](https://github.com/yuvadm/ftth-il/blob/main/README.md); [Partner SEC filing 2022](https://www.sec.gov/Archives/edgar/data/1096691/000117891322000840/zk2227367.htm)
- IPv6: Israel is at about **53%** IPv6 access per the Internet Society Pulse 2026 figure (Asia average 41%). Only the snippet was seen. — [ISOC Pulse Israel](https://pulse.internetsociety.org/en/reports/il/). A November 2023 ipv6-test.com snapshot ranked Partner first by IPv6 test count; this is old and counts tests, not adoption. — [ipv6-test.com IL](https://ipv6-test.com/stats/country/IL). RIPE allocation tables (2026) show Bezeq International with the largest IL IPv6 block. — [RIR stats IL IPv6 by LIR](https://www-public.telecom-sudparis.eu/~maigron/rir-stats/ripe-allocations/ipv6/by-lir/il-ipv6-by-lir.html). Global: Google IPv6 traffic first exceeded 50% on 2026-03-28. — [Wikipedia IPv6 deployment](https://en.wikipedia.org/wiki/IPv6_deployment)
- How to detect CGNAT: if the router's WAN address is in 100.64.0.0/10 (100.64.0.0–100.127.255.255), or differs from the public IP shown by "what is my IP", the connection is behind CGNAT. — [Connected (Hebrew)](https://www.connected.app/he/library/what-is-cgnat-x1e0ms0); [ip-trackers](https://www.ip-trackers.com/blog/port-forwarding-not-working-cgnat)
- Behind CGNAT, router port-forwards and UPnP do nothing, because inbound connections never reach the home router. The fixes are a public or static IPv4 from the ISP, IPv6, or an outbound tunnel or mesh VPN. — [ip-trackers](https://www.ip-trackers.com/blog/port-forwarding-not-working-cgnat); [xermore CGNAT guide 2026](https://xermore.com/guides/cgnat-survival-guide/)
- Mesh VPN over CGNAT: mobile networks and large ISPs often use CGNAT. "Hard NAT" (endpoint-dependent mapping) prevents direct connections, and Tailscale falls back to DERP relays or a self-hosted Peer Relay. — [Tailscale connection types](https://tailscale.com/kb/1411/connection-types); [Tailscale blog: peer relays, Jan 2026](https://tailscale.com/blog/peer-relays-international-networks); [APNIC: NAT traversal and CGNAT](https://blog.apnic.net/2022/05/03/how-nat-traversal-works-concerning-cgnats/). A hotspot showing `MappingVariesByDestIP: true` in `tailscale netcheck` points to carrier CGNAT with hard NAT; some carriers also filter UDP, which can break relays. — [zeulewan NAT notes](https://zeulewan.github.io/robot-docs-astro/networking/nat/) (community source)

### Inferences
- If the home side has a public IPv4 (Partner, Cellcom, many HOT lines, or Bezeq with a paid static IP), mesh VPNs almost always get a direct path even when the phone is on cellular CGNAT. Only one side needs to be "easy". If **both** sides are hard NAT, for example Bezeq fiber with no static IP and a phone on mobile data, expect relayed connections. Relays add latency, which matters for game streaming. Running a peer relay on the home PC, or using IPv6 on both ends, helps.
- Port forwarding Sunshine directly is impossible on default Bezeq fiber and on reportedly CGNAT ISPs. This is one more practical reason to prefer a mesh VPN.

### Gaps
- I found no **official 2025–2026** ISP pages confirming CGNAT policy or the cost of a static IP for any Israeli ISP. All ISP claims come from forum snippets dated 2022–2024, and the forum hosts could not be fetched to check exact post dates.
- I found no data on **Golan Telecom, 012/Xfone, Bezeq International (current), IBC/Unlimited retail** CGNAT policies.
- I found no reliable data on whether the **Israeli cellular networks** (Pelephone, Cellcom, Partner, HOT Mobile, Golan, 019, We4G) use CGNAT or IPv6 on mobile data. Cellular CGNAT is near-universal globally, but this is unverified for Israel.
- I found no per-ISP IPv6 enablement status (for example, whether HOT or Bezeq fiber hand out IPv6 prefixes by default in 2026).

## Q5. Dynamic DNS: is it needed with a mesh VPN?

### Takeaway
DDNS only helps when connecting directly to a home **public** IP that changes. It is useless behind CGNAT and unnecessary with a mesh VPN, which tracks peers through its coordination server and provides stable internal addresses and names.

### Cited Findings
- Behind CGNAT the public address belongs to the ISP's NAT gateway, so pointing a hostname at it reaches the ISP, not the home router. — [ip-trackers](https://www.ip-trackers.com/blog/port-forwarding-not-working-cgnat)
- A public IPv4 "may be dynamic… but it still allows port forwarding". This is the case where DDNS is needed. — [ip-trackers](https://www.ip-trackers.com/blog/port-forwarding-not-working-cgnat)
- Tailscale's device-connectivity docs say peers find each other through coordination and DERP (STUN-style discovery), with no inbound ports required. — [Tailscale connection types](https://tailscale.com/kb/1411/connection-types)

### Inferences
- With Tailscale or ZeroTier-style mesh VPNs, the stable 100.x addresses and MagicDNS names make DDNS redundant. DDNS stays relevant only for self-hosted WireGuard to a home public IPv4 that changes, for example Partner or HOT dynamic IPs. A paid static IP removes even that need.

### Gaps
- I did not research specific DDNS providers (No-IP, DuckDNS, router-built-in DDNS on Israeli ISP routers) or whether Israeli ISP routers support DDNS.
