# Research dossier: senior-game-designer

Research date: 2026-11-26. Agent file: `.claude/agents/senior-game-designer.md`.

## 1. Brief

- Role: Senior Game Designer, genre-agnostic. Core mechanics, core loop, systems design, progression and
  economy, balancing, level/encounter basics, player psychology and motivation, onboarding/FTUE, GDDs and
  one-pagers, playtest plans, design critique.
- Use: design work and documents, plus small playable HTML/JS prototypes (canvas or DOM, no heavy engine)
  in a dedicated folder (`prototypes/<name>/`) that never touches the existing app.
- Seniority: senior. Market: global plus Israel (Playtika, Moon Active, Plarium, Supersonic/Unity, SuperPlay, indies).
- Answer language: Hebrew; documents in English on request.
- Hard limits: do not modify `www/`, Capacitor config, `signing/`, `.github/` unless explicitly asked; no
  recreations/clones of specific commercial games (names, characters, art, music, levels, look); no dark
  patterns exploiting minors or gambling-like mechanics without clearly flagging ethical/legal risk.
- Repo context: `giulietta-app` is a personal car-maintenance tracker (www/index.html, Capacitor APK via
  GitHub Actions). The agent is a general specialist, not tied to that app.

## 2. Assumptions

1. "Senior" = 5+ years, owns a pillar/system end to end, mentors; this is the modal bar in postings (J1, J2, J3, J11).
2. Genre-agnostic, but the Israeli market is dominated by F2P mobile (casual, social casino, hybrid-casual, puzzle),
   so economy, LiveOps and monetization literacy is weighted higher than in a pure PC/console brief.
3. Prototypes are throwaway, single-folder, dependency-free (no CDN, no npm install) so they run offline and can be
   opened by double-click or `python3 -m http.server`. Node is used only for syntax checks and headless simulations.
4. The agent does not commit, push or publish; the user decides.
5. Placeholder art only (geometric shapes, emoji-free, generated colors); no third-party assets.
6. The installed `design-taste-frontend` skill is NOT preloaded: it is a marketing-website skill (landing pages,
   company sites) with a Stop hook that runs a website "finish gate"; it does not fit game prototypes and its gate
   would add noise or false failures.

## 3. Method and limitations

- Searches run in `extended` mode for job postings, regulation and trends; `standard` for reference facts.
- **Limitation:** WebFetch failed with DNS/allow-list errors for hitmarker.net, coolgames.com, remotejobs.org,
  outscal.com and freehire.me in this sandbox; per tool guidance I stopped trying further hosts. Page content below
  therefore comes from the search engine's extended-mode extraction of the actual pages (quoted fragments), not from a
  full page read. Every kept claim is tied to a specific URL; where the extract flagged uncertainty (stale, closed,
  aggregator, conflicting dates) it is recorded. Recommend allowing these domains if a re-verification pass is wanted.

## 4. Job-posting evidence

| # | Employer / role | Location | Date (as reported) | Key requirements extracted |
|---|---|---|---|---|
| J1 | SOFTGAMES, Senior Game Designer, Systems & Economy (Solitaire TriPeaks) | Remote EU/DE | 2026 (multiple versions, some archived) | 5+ yrs F2P mobile, shipped/live titles; systems, economy, progression, LiveOps; economy models, balancing/simulation/forecasting spreadsheets; KPIs retention, ARPDAU, conversion, LTV; work with Product, BI, UA, Art, Dev; AI-tool proficiency; English; design test |
| J2 | Arrowhead Game Studios, Senior Game Designer (Helldivers 2 missions) | Stockholm, hybrid | Nov 2026 | ~5+ yrs AA/AAA, 1+ shipped title personally implementing missions/encounters/systems; ideate, build, script, balance, debug in engine; draft core loop, flow, win/fail, script prototype (aggregator wording); Lua/Python/C# scripting, state machines; telemetry, completion rates, player feedback for post-launch balance |
| J3 | Epic Games, Senior (Gameplay) Game Designer, Fortnite | US | Aug 2026 | 5+ yrs (2+ shipped for Sr.); Unreal Blueprint, implement in engine; design, prototype, implement, ship; own features end to end; GaaS/live-service; cross-discipline collaboration |
| J4 | Unity (Supersonic), Senior Game Designer, Hybrid Casual | Tel Aviv | 2026 (open status unconfirmed) | 2+ yrs mobile, hybrid-casual focus; create and iterate playable prototypes solo and in team; pitch concepts; tune balance and pacing |
| J5 | Moon Active, Game Designer / Product Game Designer | Tel Aviv, hybrid | undated (Built In / Jobify) | experience in game, product or content design; create, review, manage designs; build new gameplay elements; use data to analyze, tune, improve; support Art, UI, Production, QA; portfolio |
| J6 | Plarium, Game Designer (new third-person shooter) | Kharkiv/Lviv | posted 2026-09-24 (aggregator) | 2+ yrs; GDD writing; in-game economy creation; probability and game theory; Excel/Google Sheets; (RAID listing) system design and analytical data skills |
| J7 | Redux Games (SayGames), Senior Game Designer | Remote | dates conflict (possibly reposted) | 3+ yrs mobile design, 2+ on monetization; owns features end to end; designer-producer mindset, tracks results |
| J8 | SuperPlay, Level Designer | Tel Aviv | closed | 2+ yrs level/game design; inventive gameplay; technical understanding of systems; casual mobile; cross-functional with Product, Eng, Art, QA |
| J9 | Playtika, Senior Level Designer, Solitaire Grand Harvest | Israel on-site (also Spain) | ~2026 (aggregator) | design, balance, test new levels; smooth difficulty progression; fun factor and UX with QA |
| J10 | Gameloft, Lead Game Designer (PC/console/mobile) | Remote US | Oct 2026 | prototype core combat loop directly in Blueprints; 2+ titles as lead/principal/senior |
| J11 | coolgames, Senior Game Designer, Systems & LiveOps | Remote/on-site | 2026-02-05 | 5+ yrs mobile/web F2P; economy sinks and taps, difficulty scaling, reward pacing; events, content drops, experiments; ARPU, LTV, conversion; analytics tools (SQL/Python/Looker, per search extract) |
| J12 | Awe Plc, Senior Game Designer | US | ~Oct 2026 | 1+ shipped PC/console title; Unreal Engine 5, Blueprints, data tables |
| J13 | Nimble Giant, Senior Game Designer | remote/AR | spring 2026 | 3+ yrs PC/console, 1+ shipped; combat and encounter design |
| J14 | Fifty Cats (via AllJobs), Game Designer | Tel Aviv / remote | undated | game design experience, portfolio, storytelling and character development, Photoshop/Illustrator |

Employers: 14 distinct (4 with Israeli roles: Moon Active, Unity/Supersonic, SuperPlay, Playtika, plus Fifty Cats via AllJobs).

### Requirement frequency (J1–J14)

| Requirement | Count | Postings | Tag |
|---|---|---|---|
| Balancing / tuning (levels, difficulty, pacing, systems) | 7 | J1 J2 J4 J5 J8 J9 J11 | core |
| Senior-level experience (5+ yrs or lead/shipped multiple) | 6 | J1 J2 J3 J10 J11 (J7 3+) | core |
| Shipped / live titles | 6 | J1 J2 J3 J10 J12 J13 | core (human-only; out of scope for agent) |
| Hands-on prototyping (playable, in engine/scripting) | 5 | J2 J3 J4 J10 J12 | core |
| Data / KPIs / telemetry driven iteration | 5 | J1 J2 J5 J6 J11 | core |
| Cross-functional collaboration and communication | 5 | J1 J3 J5 J8 J10 | core |
| Economy / progression / currencies / sinks-taps | 4 | J1 J6 J7 J11 | core |
| Scripting / engine implementation | 4 | J2 J3 J10 J12 | core |
| LiveOps / GaaS / events | 4 | J1 J3 J11 J2(post-launch) | core |
| Level / mission / encounter design | 4 | J2 J8 J9 J13 | core |
| Feature ownership end to end | 3 | J3 J7 J2 | core |
| Spreadsheet models / simulation / forecasting | 3 | J1 J6 J11 | core |
| Monetization design | 3 | J1 J7 J11 | core |
| Design documentation (GDD) | 3+ | J6 J5 (+PC/console summary J2/J3/J10) | core (also O*NET) |
| Pitching concepts / market fit | 2 | J4 J5(product) | supporting |
| Portfolio / design test | 3 | J1 J11 J5 J14 | supporting (hiring artefact) |
| Probability and game theory | 1 | J6 | niche (kept: gacha odds, drop tables) |
| AI-tool proficiency | 1 | J1 | niche in postings, but core trend (S20, S21) |
| Narrative/character development | 1 | J14 | niche (kept lightly) |

## 5. Occupational standards

- **O*NET 15-1255.01 Video Game Designers** (S15): design core features (mechanics, story, characters); maintain design
  documentation; create gameplay prototypes for review; write gameplay test plans; create missions/puzzles; balance
  gameplay; work with art on visual style; work with production to build as designed. Tech: Photoshop, Illustrator,
  Maya, Git, Perforce. Skills: complex problem solving, systems thinking, originality, written communication.
  Software list from 2025 postings; tasks from 2022 expert review.
- **ESCO / ISCO 2166.7 Digital games designer** (S16, via secondary reproductions; official portal not fetched):
  essential skills incl. formulate game rules, create software design, digital game genres, digital game creation
  systems, systems development life-cycle, task algorithmisation, web programming; optional Unity, 3D lighting.
- Mapping: O*NET 15-1255.01 (primary), ISCO-08 2166 / ESCO "digital games designer" (primary EU).

## 6. Professional bodies and certifications

- **No licensing body and no universally recognized game-design certification** (S17). IGDA is the largest
  professional association (150+ chapters) but its "Certified Game Designer" claim appears only on a low-authority
  blog and could not be verified (contradiction flagged). Hiring signals are portfolio, shipped titles and design
  tests (J1, J11, J5, J14), not certificates.
- Consequence for the agent: no certificate body of knowledge to embed; canonical texts and talks serve as the
  de facto BoK (S8–S14).

## 7. Standards, regulation, law (jurisdiction noted)

| Item | Jurisdiction | Status / date | Design impact | Src |
|---|---|---|---|---|
| PEGI "interactive risk" criteria: paid random items => min PEGI 16 (18 possible); time/quantity-limited offers => min PEGI 12; NFT/blockchain => PEGI 18 | Europe (PEGI countries) | new submissions from June 2026; retroactive move of digital-only titles reported Oct 2026 (fewer sources) | loot boxes, gacha, card packs, prize wheels raise age rating regardless of cosmetic-only | S22 |
| EU Digital Fairness Act proposal COM(2026) 1100 | EU | proposed 11 Nov 2026, NOT law | "paid variable reward systems": show odds, switch-off; banned for minors with pay-to-win; virtual-currency items show real-money value; paid currency off by default for minors | S23 |
| Brazil ECA Digital, Law 15.211/2025 Art. 20, Decree 12.880/2026 | Brazil | in force 17 Mar 2026; scope interpretations differ | paid loot boxes restricted for minors; age assurance; enforcement against major titles | S24 |
| FTC v. HoYoverse (Genshin Impact) | US | settlement announced Jan 2025 | $20M; no loot boxes to under-16 without parental consent; disclose odds and currency exchange rates; COPPA; deceptive odds/costs = violation | S25 |
| Belgium (regulator ruling 2018), Netherlands, UK Ukie 11 principles | BE / NL / UK | BE effective ban; UK self-regulation under review | disclose loot boxes before purchase, parental controls | S26 |
| Apple App Store (2017) / Google Play (2019) odds disclosure | Global stores | in force; verify current text | disclose odds before purchase | S27 |
| Israel Penal Law s.224 predominance test; class action vs EA over FIFA loot boxes | Israel | pending; no ruling that loot boxes are gambling | chance-dominant paid mechanics carry legal risk in Israel | S28 |
| Israel Privacy Protection Law Amendment 13 | Israel | in force 14 Aug 2025 | personal data in games (incl. minors: parental consent via capacity law) | S29 |
| Game Accessibility Guidelines (basic/intermediate/advanced); Xbox Accessibility Guidelines v3.2 | Industry standard | GAG current; XAG 3.2 (Jun 2023) | accessibility baseline in every design | S30 |

## 8. Practitioner and trend sources

- S8 MDA (Hunicke, LeBlanc, Zubek 2004): designers control mechanics, players experience aesthetics first; 8 aesthetics; criticism: mechanics-centric.
- S9 Schell, *The Art of Game Design: A Book of Lenses*, 3rd ed., CRC Press 2019: 100+ lenses (question sets) for iterative design.
- S10 Daniel Cook, "Loops and Arcs" (Lostgarden 2012) and skill atoms/chains ("Chemistry of Game Design"); Koster's game atoms.
- S11 Adams & Dormans, *Game Mechanics: Advanced Game Design* (Machinations; ch. 5 Machinations, ch. 9 Building Economies); Machinations.io; sources/sinks inflation logic; Monte Carlo simulation before build.
- S12 Quantic Foundry Gamer Motivation Model: 12 motivations in 6 pairs, 3 clusters, from factor analysis of large survey samples (critique: preferences vs traits).
- S13 Celia Hodent, *The Gamer's Brain* + GDC 2016 "UX of Onboarding and Player Engagement": usability vs engage-ability; onboarding pitfalls; how the brain learns.
- S14 Stone Librande, GDC 2010 "One-Page Designs" and GDC 2013 SimCity: concise visual docs; long GDDs go unread; GDD as living document.
- S18 Playtesting: Brian Cronin GDC 2026 "Playtesting Process for Ultra Small Teams" (1:1 synchronous sessions, interviewing, follow-up); in-house playtesting to remove bias; tie playtests to decisions; recruit target players; aggregate analysis.
- S19 Senior vs junior: Ask a Game Dev; 8bitplay career guide; Game Developer "Types of designers": seniors own a pillar or interlocking systems, judgment and written communication, mentoring, "make problems go away".
- S20 GDC State of the Game Industry, Nov 2026: 40% use generative AI at work (36% prior year), 57% of users daily; designers and artists 65% negative on AI's impact.
- S21 Vibe-coding / AI prototyping 2026 (multiple guides, Simon Willison Oct 2026 quoted): prototyping is the strongest use case; AI gets ~70% fast then fixes break things; browser + Three.js/vanilla common.

## 9. Competency model

Evidence tags: C = core (>=3 sources or official standard), S = supporting (2), N = niche (1).

**Mission.** Turn a target player experience into a small set of rules, loops and content that are fun, learnable,
balanced and sustainable, prove it fast with prototypes and playtests, and communicate it so a team can build it.

**Core tasks (ranked)**
1. Define and iterate core mechanics and core loop; draft flow and win/fail conditions — C (J2, J3, J10, O*NET S15, S8, S10)
2. Prototype the riskiest idea quickly and iterate — C (J2, J3, J4, J10, J12, S15, S21)
3. Balance and tune (difficulty, pacing, numbers) — C (7 postings, S15)
4. Design systems, economy and progression (sources/sinks, currencies, reward pacing) — C (J1, J6, J7, J11, S11)
5. Model/simulate in spreadsheets or code before shipping — C (J1, J6, J11, S11)
6. Write and maintain design docs (one-pagers, GDD) — C (J6, S15, S14, S16)
7. Plan and run playtests; use telemetry and KPIs — C (J1, J2, J5, J11, S15 test plans, S18)
8. Level/mission/encounter design basics — C (J2, J8, J9, J13, S15)
9. Onboarding/FTUE design — S/C (S13, J9 UX, J4 pacing)
10. Critique and review designs; mentor — C (J5 review designs, S19, J3 ownership)

**Knowledge:** MDA (C: S8, S9, S10), loops and arcs/skill atoms (S: S10, J2), economy theory sources/sinks/inflation (C: J1, J11, S11),
probability/expected value/game theory (N: J6, kept for loot/drop tables), player motivation models (S: S12, S13),
F2P KPIs (C: J1, J11, J5), genres (C: S16, J-postings), accessibility guidelines (C: official S30),
monetization regulation (C: official S22–S29).

**Skills:** systems thinking (C: S15, J1, J8), numerical balancing (C), rapid prototyping/scripting (C), written
communication/one-page docs (C: S14, S15, S19), playtest facilitation without leading (S: S18, S13), data
interpretation (C), pitching (S: J4, J5).

**Tools:** spreadsheets (C: J1, J6, J11), engine scripting Lua/Python/C#/Blueprint (C: J2, J3, J10, J12),
Machinations (N: S11), analytics SQL/Python/Looker (N: J11), version control Git/Perforce (S: S15), AI tools (S: J1, S20, S21).
For this agent: HTML/JS canvas/DOM, Node for checks and simulations (brief).

**Judgment and quality bar:** every mechanic serves a stated experience goal (S8, S9); meaningful decisions; numbers
backed by a model, not gut (J1, S11); one question per prototype (S21, J4); playtest tied to a decision (S18);
docs short enough to be read (S14); usability and engagement both checked (S13); accessibility baseline (S30).

**Seniority signals:** owns a pillar or interlocking systems end to end (S19, J3, J7); judgment and written
communication (S19); thinks like designer and producer, tracks results (J7); balances player experience against
business goals "without hurting the player experience" (J1); mentors.

**Common mistakes:** documents nobody reads (S14); onboarding pitfalls, text-wall tutorials (S13); balancing without
models leading to inflation (S11); biased playtests and leading questions (S18); AI-generated prototype code that
breaks when patched (S21); designing mechanics without regard to experienced aesthetics (S8).

**Ethical, legal, safety limits:** deceptive odds and cost obfuscation (S25); paid random items and minors (S22–S26);
Israeli gambling-law exposure (S28); privacy of player data incl. minors (S25 COPPA, S29); clones/IP (brief).
Escalate to a lawyer, rating body, or publisher compliance before shipping any of these.

## 10. Embed / Tool / Human / Out-of-scope mapping

| Competency | Decision | Note |
|---|---|---|
| Core loop, mechanics, MDA, loops/arcs, lenses | Embed | operating method + checklists |
| Economy/progression modeling | Embed + Tool (Write, Bash/node) | CSV/JS simulations in prototype folder |
| Balancing curves | Embed + Tool | formulas, sim scripts, tunable CONFIG |
| Prototyping in HTML/JS | Tool (Write/Edit/Bash) | `prototypes/<name>/` only |
| Engine scripting (Unity/Unreal/Lua) | Embed (advice only) | brief excludes heavy engines |
| Docs (one-pager, GDD, playtest plan) | Embed + Tool (Write) | templates in prompt |
| Playtest facilitation with real players | Human-in-the-loop | agent writes plan/script; human runs sessions |
| Telemetry/KPI analysis | Embed + Tool (Read data files) | only on data user provides |
| Market/competitor research, regulation check | Tool (WebSearch/WebFetch) | freshness rule |
| Monetization/legal compliance sign-off | Human-in-the-loop | lawyer / rating body |
| Shipping, store submission, publishing | Human-in-the-loop | |
| Shipped-title experience, portfolio, design test | Out of scope | hiring artefacts, not transferable |
| Final art, audio, 3D | Out of scope | placeholder only |
| People management / studio leadership | Out of scope | |

## 11. Contradictions flagged

- Years of experience for "senior": 2+ (J4) vs 3+ (J7, J13) vs 5+ (J1, J2, J3, J11). Modal = 5+.
- IGDA certification exists (low-authority blog) vs no recognized certification (S17). Treated as none.
- PEGI loot-box rule: June 2026 for new submissions (most sources) vs retroactive Oct 2026 move (fewer sources).
- Brazil ECA Digital: blanket under-18 ban vs ban keyed to age rating; enforcement routes via decree.
- EU DFA: the 25% minors-audience threshold came from a leaked draft; not confirmed in published text.
- Apple/Google odds-disclosure sources are 2017/2019; current text must be verified.
- AI: adoption rising (40%) while designers are among the most negative (65%). Agent uses AI-built prototypes but keeps human judgment and original IP central.

## 12. Sources (accessed 2026-11-26 unless noted)

Job postings
- J1 SOFTGAMES, Senior Game Designer - Solitaire TriPeaks (Systems & Economy). https://jobs.softgames.de/o/senior-game-designer-systems-economy-fully-remote-1 (also remotive.com/remote-jobs/design/senior-game-designer-2080526). 2026.
- J2 Arrowhead Game Studios, Senior Game Designer. https://jobs.arrowheadgamestudios.com/jobs/8690387-senior-game-designer ; aggregator https://www.dreamworkhq.com/job/e8f05524-5f33-4ccb-a6c8-afda030e2dcd . Nov 2026.
- J3 Epic Games, Senior Gameplay Designer, Fortnite. https://builtin.com/job/senior-gameplay-designer/2113308 ; https://zapply.jobs/jobs/18a72e36-1472-492b-9751-73828c88a49e/ . Aug 2026.
- J4 Unity, Senior Game Designer (Hybrid Casual), Supersonic, Tel Aviv. https://unity.com/careers/positions/6962738 ; https://gamejobs.co/Senior-Game-Designer-Supersonic-at-Unity . 2026.
- J5 Moon Active, Game Designer / Product Game Designer, Tel Aviv. https://builtin.com/job/product-game-designer/9001897 ; https://jobs.ashbyhq.com/moonactive ; https://il.linkedin.com/jobs/view/game-designer-at-moon-active-3791546081 (closed). Undated.
- J6 Plarium, Game Designer. https://company.plarium.com/en/career/game-design-and-analytics-game-designer-kharkiv/ ; https://jobs.christran.gg/studios/plarium (Nov 2026 snapshot, posted 2026-09-24).
- J7 Redux Games (SayGames), Senior Game Designer. https://saygameshr.global.huntflow.io/vacancy/senior-game-designer-redux-games ; https://ingamejob.com/job/senior-game-designer-153 . Dates conflict.
- J8 SuperPlay, Level Designer, Tel Aviv. https://jobs.generalcatalyst.com/companies/superplay/jobs/86158929-level-designer . Closed.
- J9 Playtika, Senior Level Designer - Solitaire Grand Harvest. https://outscal.com/job/senior-level-designer-solitaire-grand-harvest-at-playtika-in-israel-1 . ~2026.
- J10 Gameloft, Lead Game Designer (PC/Console/Mobile). https://freehire.me/jobs/lead-game-designer-pc-console-mobile-gameloft-qi5765qo . Oct 2026.
- J11 coolgames, Senior Game Designer (Systems/LiveOps). https://www.coolgames.com/2026/02/05/senior-game-designer-systems-liveops-remote-or-on-site-full-time/ . 2026-02-05.
- J12 Awe Plc, Senior Game Designer. https://www.wearedevelopers.com/jobs/ext/4010269-senior-game-designer . ~Oct 2026.
- J13 Nimble Giant, Senior Game Designer. https://careers.nimblegiant.com/jobs/544977-senior-game-designer . Spring 2026.
- J14 Fifty Cats, Game Designer (AllJobs). https://www.alljobs.co.il/Search/UploadSingle.aspx?JobID=7055130 . Undated. Also Israeli board overview https://gamedev.co.il/he/jobs/designers (33 open roles at time of search).

Standards, bodies, regulation
- S15 O*NET OnLine, 15-1255.01 Video Game Designers. https://www.onetonline.org/link/summary/15-1255.01 . Tasks 2022, tech 2025.
- S16 ESCO/ISCO 2166.7 Digital games designer (reproductions). https://www.openriskmanual.org/wiki/ISCO_Occupation_Group_2166.7_Digital_Games_Designer ; https://tyomarkkinatori.fi/en/personal-customers/professional-information/professions/game-designer (ESCO 1.2.1).
- S17 IGDA. https://igda.org/about/ ; https://en.wikipedia.org/wiki/International_Game_Developers_Association ; https://resumecat.com/blog/game-designer-certifications (low authority).
- S22 Reed Smith, "PEGI launches interactive risk categories". https://www.reedsmith.com/articles/pegi-launches-interactive-risk-categories-overhauls-age-ratings-for-loot-boxes-in-game-spending-and-communication-features/ ; https://esportslegal.news/2026/03/30/pegi-2026-new-risk-ratings/ (2026-03-30).
- S23 EU Digital Fairness Act proposal. https://www.paulweiss.com/insights/client-memos/european-commission-proposes-the-digital-fairness-act ; https://mobilegamer.biz/eus-draft-digital-fairness-act-takes-aim-at-loot-boxes-virtual-currencies-and-pay-to-win/ . Nov 2026.
- S24 Brazil ECA Digital. https://factotumcom.substack.com/p/brazil-digital-eca-bans-loot-boxes ; https://www.lickslegal.com/articles/brazil-s-first-loot-box-ruling-key-takeaways-for-digital-companies/ . 2026.
- S25 FTC, HoYoverse settlement. https://ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse . Jan 2025.
- S26 Loot box status overview (Belgium, NL, UK Ukie principles). https://link.springer.com/article/10.1007/s40429-022-00424-9 ; https://cms.law/en/gbr/legal-updates/loot-boxes-11-new-principles-for-an-industry-led-approach .
- S27 Apple / Google odds disclosure. https://www.fenwick.com/insights/publications/apple-now-requires-disclosure-of-loot-box-odds ; https://fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds . 2017/2019.
- S28 Israel: EA FIFA loot-box class action. https://www.calcalistech.com/ctechnews/article/skkdqehnml (~Oct 2026) ; Herzog, Israel gaming law. https://herzoglaw.co.il/wp-content/uploads/2020/01/gaming.pdf .
- S29 Israel PPL Amendment 13. https://www.loc.gov/item/global-legal-monitor/2025-11-17/israel-amendment-to-privacy-protection-law-goes-into-effect/ (2025-11-17) ; https://chambers.com/practice-guides/guides/data-protection-privacy-2026/israel/law-and-practice .
- S30 Game Accessibility Guidelines https://gameaccessibilityguidelines.com/ ; Xbox Accessibility Guidelines https://learn.microsoft.com/en-us/gaming/accessibility/guidelines (v3.2, 2023-06-08).

Practitioner and trends
- S8 Hunicke, LeBlanc, Zubek, "MDA: A Formal Approach to Game Design and Game Research" (AAAI WS-04-04, 2004). https://users.cs.northwestern.edu/~hunicke/MDA.pdf
- S9 Schell, The Art of Game Design: A Book of Lenses, 3rd ed., CRC Press, 2019. https://www.routledge.com/The-Art-of-Game-Design-A-Book-of-Lenses-Third-Edition/Schell/p/book/9781138632059
- S10 Cook, "Loops and Arcs" (Lostgarden, 2012) and skill atoms. https://par.nsf.gov/servlets/purl/10049718 ; https://www.raphkoster.com/?p=4090
- S11 Adams & Dormans, Game Mechanics: Advanced Game Design (ch. 5, 9). https://www.oreilly.com/library/view/game-mechanics-advanced/9780132946728/ch09.html ; https://machinations.io/articles/what-is-game-economy-design
- S12 Quantic Foundry Gamer Motivation Model. https://quanticfoundry.com/wp-content/uploads/2019/04/Gamer-Motivation-Model-Reference.pdf ; https://quanticfoundry.com/faq/
- S13 Hodent, GDC 2016 "The Gamer's Brain, Part 2: UX of Onboarding and Player Engagement". https://gdcvault.com/play/1022951/ ; GDC Podcast ep. 8 https://www.gamedeveloper.com/design/games-psychology-and-ux-with-celia-hodent---gdc-podcast-ep-8
- S14 Librande, GDC 2010 "One-Page Designs". https://gamedeveloper.com/design/video-one-page-designs ; https://en.wikipedia.org/wiki/Game_design_document
- S18 Cronin, GDC 2026 "Playtesting Process for Ultra Small Teams". https://gdcvault.com/play/1035679/Playtesting-Process-for-Ultra-Small ; https://gdcvault.com/play/1016497/Implementing-an-In-House-Playtesting ; https://gamedeveloper.com/design/best-practices-five-tips-for-better-playtesting
- S19 Senior vs junior. https://askagamedev.tumblr.com/post/186565732886/what-does-it-mean-to-be-junior-mid-level-or ; https://8bitplay.com/blog/game-designer-career-specialisations-growth-paths/ ; https://www.gamedeveloper.com/design/types-of-designers
- S20 GDC State of the Game Industry, Nov 2026. https://gdconf.com/state-of-the-game-industry-november-2026/ ; https://gamedevreports.substack.com/p/gdc-the-state-of-the-game-industry-52b
- S21 Vibe coding games 2026. https://www.strayspark.studio/blog/vibe-coding-game-development-2026 ; https://vlstudio.app/blog/vibe-coding-a-game-2026/

Total: 14 job postings (14 employers) + 23 other sources.
