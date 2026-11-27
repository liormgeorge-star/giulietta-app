# Research dossier: kids-learning-content-designer

Research date: 2026-11-27. Agent file: `.claude/agents/kids-learning-content-designer.md`.

## 1. Brief

- Role: Senior educational content developer / instructional designer for Hebrew-speaking children, Israeli
  elementary school, grades 1-6 (ages ~6-12).
- Subjects: general knowledge and science; math (arithmetic etc.); English as a foreign language (Israeli EFL
  curriculum); Hebrew language and reading (literacy, niqqud, reading comprehension).
- Use: (1) write content for the user's kids' learning web games (questions, options with good distractors,
  short explanations/facts, exercises, leveled by grade, Hebrew with correct full niqqud where appropriate,
  verified facts); (2) review existing games (age fit, curriculum alignment, pedagogy, accuracy, reading level,
  accessibility, motivation, child safety) and hand back concrete content fixes. Examples: "טריוויה לילדים"
  (8 categories, 2 levels), "מסע החשבון", "כרטיסיות אנגלית / Flip & Learn" (claude.ai artifacts, single-file HTML).
- Works alongside `senior-game-designer` (mechanics, UX, prototype code). This agent owns content and pedagogy;
  may edit content data in given game files, not logic/code unless asked.
- Seniority: senior. Market: Israel first (MoE curriculum, Pop, RAMA, EFL bands/CEFR) plus global best practice.
- Answer language: Hebrew.
- Hard limits: no changes to `www/`, `signing/`, `.github/`, Capacitor config; no commits/pushes; verified facts with
  uncertainty flagged; age-appropriate and inclusive, no gender-only phrasing; child privacy; no dark patterns.

## 2. Assumptions

1. "Senior" = 5-8+ years of content development, usually after elementary teaching; writes and edits others' items
   (J1, J4, J13 ask 4-5+ years; J18 5-10 years).
2. The games are small, single-file HTML artifacts with content held in JS arrays/objects; content edits can break
   JS syntax (Hebrew abbreviations with ASCII quotes), so the agent gets Bash solely for `node --check` validation
   and item counts in the scratchpad. This is the only reason Bash is granted.
3. The two difficulty levels of the trivia game map by default to grades 1-3 and 4-6; the agent states this and the user can change it.
4. Option counts per grade (2-3 for grades 1-2, 3-4 for grades 3-6) are a house default derived from the reading-load
   principle, not an official standard; labelled as such in the prompt.
5. The formal start grade of school English is treated as "verify before stating": sources found describe Pre-Foundation
   by end of grade 3 and K-2 exposure programs (ENJOY ENGLISH) but no current official statement of the start grade.
6. No installed skill fits (`design-taste-frontend` is for marketing websites; `game` and `recruit` are dispatch skills),
   so none is preloaded.
7. Existing agents checked: `agent-recruiter`, `senior-game-designer`. No overlap in content/pedagogy; the game designer
   explicitly owns mechanics/UX/code, so a new agent is created rather than an upgrade.

## 3. Method and limitations

- 40+ searches, extended mode for postings, Israeli curriculum, regulation and trends; standard mode for reference facts.
- **Limitation:** WebFetch failed with DNS/allow-list errors (`ENOTFOUND`) for careers.mheducation.com, www.edtech.com and
  cet.ac.il in this sandbox. Per tool guidance, no further hosts were tried. Content below comes from the search engine's
  extended-mode extraction of the actual pages (quoted fragments), not a full page read. Every kept claim is tied to a URL;
  where the extract flagged staleness, closure, aggregation or conflicts, this is recorded. Allowing these domains would
  permit a full re-verification pass.

## 4. Job-posting evidence

| # | Employer / role | Location | Date (as reported) | Key requirements extracted |
|---|---|---|---|---|
| J1 | McGraw Hill, Senior Instructional Designer, Science (K-12) | US remote | 2026 (several versions, one expired) | BA/MA instructional design or related; 3-5 / 4-5 yrs digital content development incl. teaching and learning materials; K-12 teaching and publishing preferred; authoring tools, LMS/CMS, interactive content; accessibility built in, compliance criteria; cross-functional; flag risks early |
| J2 | McGraw Hill, Instructional Designer K-5 ELA | US remote, contract | 2026-10-19 | degree in ID or related; familiarity with K-12 publishing, edtech platforms, literacy curriculum design; ~$65-75k |
| J3 | McGraw Hill, Senior Academic Designer, Literacy (K-2 / 3-6) | US | 2026 (project role ending 7/31/2026) | BA education/literacy/linguistics; 4+ yrs literacy curriculum development K-2 |
| J4 | K12 Inc. (Stride), Senior Instructional Designer | US remote | 2026-06-27 | standards-aligned online courses K-12; 5+ yrs curriculum development; Articulate Storyline / Adobe Captivate |
| J5 | MGT Impact Solutions, K-5 Math Curriculum Writer | US remote | Apr/Jun 2026 start | standards-aligned units, lessons, tests; bachelor's; familiarity with AI tools required |
| J6 | QBS Learning, K-5 Math Content Writer (contract; via aggregators) | US remote | ~2026 (aggregator, ~290 days old) | lessons, practice items, assessments, teacher support; align to Common Core/state standards; revise after editor and SME feedback; 3+ yrs (one listing says 5); elementary math pedagogy |
| J7 | Zeta Charter Schools, Elementary Math Curriculum Writer Consultant | New York | 2026-11 | problems, lessons, assessments aligned to NYS math standards, grades 2-5 |
| J8 | Fishtank Learning, Math Curriculum Writer Grades 3-5 | Boston/remote | listing 2026-09-12; start 2026-07-01 (possibly stale) | 2+ yrs curriculum writing + 4-5 yrs elementary classroom teaching |
| J9 | Khan Academy Kids, Bilingual Content Creator (24-month) | US/Canada remote (one listing on-site) | mid-Sep 2026 | author standards-aligned activities and assessment items PreK-2 (Head Start ELOF, Common Core, state PreK); map content coverage and crosswalks; revise from child data and psychometrics; test items with children and educators; editorial reviewer; 2+ yrs content dev or teaching; data and learner feedback; JSON/SQL willingness; structured content files and Git |
| J10 | Kiddom, Math Content Writer / Instructional Designer - Math | US remote | 2025-2026 (some closed) | 3+ yrs teaching math; Common Core and state standards; author/edit interactive question types on the platform; GenAI proficiency in ID workflows |
| J11 | Illustrative Mathematics, Math and PL Content Writer | US remote | 2026 | 3+ yrs math content (TK-6 etc.); CCSS and Progressions documents; $79.5-90k |
| J12 | Edmentum, Content Designer K-5 Math | US | 2026 (aggregator) | BA in education or content field, MA preferred; 1 yr education/curriculum; strong math expertise |
| J13 | CET (מטח), מפתח/ת תוכן באנגלית | Ramat Aviv, hybrid | first posted 2022-12, reposted on boards | native English (must); 5+ yrs teaching English in elementary/middle school (must); excellent writing; high-level Hebrew; BA; advantage: pedagogical development in English; develops learning and teaching processes in print and digital with development teams |
| J14 | CET (מטח), מפתח/ת למידה + career page "מפתח תוכן פדגוגי במתמטיקה" | Israel | 2026 (freehire/CET) | 2+ yrs creating digital learning products; Storyline; take a pedagogical need, crack it with product partners, lead it to a clear, experiential digital product |
| J15 | Israeli learning-design postings (Amarel "מעצב.ת חווית למידה", John Bryce, Jobify, HIT TELEM board) | Israel | 2026 (mixed) | Storyline/Rise/Camtasia/Canva/Genially; 2-3 yrs (senior 3+); learning-technology degree; high-level English; AI an advantage |
| J16 | Matific, Junior Educational Game Developer | Ramat Gan | 2026 (LinkedIn) | educational math games; R&D with game design teams |
| J17 | AllJobs listing, כותב.ת מערכים לילדים 3-6 | Tel Aviv / home | undated | degree (or near), strong Hebrew, writing skills |
| J18 | Undisclosed K-12 publisher via Virtual Vocations, Senior Instructional Designer 6-12 ELA | US remote | 2026-10 | 5-10 yrs; digital learning experiences; accessibility standards and UDL; mentorship |

Employers: 15+ distinct (Israeli: CET x2, Matific, AllJobs employer, Amarel and other learning-design employers).

### Requirement frequency (J1-J18)

| Requirement | Count | Postings | Tag |
|---|---|---|---|
| Standards / curriculum alignment | 9 | J1 J4 J5 J6 J7 J9 J10 J11 J13 | core |
| Writing practice items / assessment items / problems | 6 | J5 J6 J7 J9 J10 J12 | core |
| Experience band 2-5+ yrs (senior 4-5+) | 10 | J1 J3 J4 J6 J8 J9 J10 J11 J13 J18 | core (human-only) |
| Classroom teaching experience in subject/grade | 6 | J1 J8 J10 J11 J13 J9 | core (embedded as "former teacher" judgment) |
| Subject-matter and pedagogy expertise (math pedagogy, literacy, EFL) | 7 | J2 J3 J6 J10 J11 J12 J13 | core |
| Degree (education / ID / content) | 7 | J1 J2 J3 J5 J12 J13 J15 | core (human-only) |
| Digital / interactive content, authoring tools | 6 | J1 J4 J10 J14 J15 J9 | core (agent edits HTML data; authoring tools out of scope) |
| Excellent writing and editing; language fluency | 5 | J9 J13 J17 J6 J2 | core |
| Revise from feedback or data (editor, SME, child data) | 3 | J6 J9 J10 | core |
| Accessibility / UDL | 2 | J1 J18 | supporting (core via IS 5568 / WCAG / UDL standards) |
| AI tools proficiency | 4 | J5 J10 J15 J14(implicit) | core trend |
| Cross-functional collaboration (dev, product, art) | 3 | J1 J13 J14 | core |
| Content coverage mapping / crosswalks | 1 | J9 | niche, kept (category/grade coverage tables) |
| Testing items with children | 1 | J9 | niche, kept (playtest hand-off) |
| Structured data (JSON, Git) | 1 | J9 | niche, kept (question arrays) |
| Game-based learning | 2 | J14 J16 | supporting |

## 5. Competency model (evidence tags: C core / S supporting / N niche; numbers = sources in section 8)

**Mission.** Turn learning objectives from the Israeli curriculum into accurate, age-appropriate, diagnostically useful
and engaging content for children's games, and keep existing content to that bar. (C: J1-J13, 1)

**Core tasks (by frequency).**
1. Write standards-aligned practice and assessment items with feedback (C: J5-J10, J12, 1).
2. Align and tag content to curriculum and grade; map coverage (C: J1, J4-J11, J13, 6-10).
3. Review and revise content from editor, SME and learner data (C: J6, J9, J10).
4. Verify accuracy of facts and answers (C: 1, 23, 24; J6 SME review).
5. Level language and reading load; niqqud (C: 7, 8, 11).
6. Collaborate with developers/designers; hand off mechanics issues (C: J1, J13, J14).

**Knowledge.**
- Israeli MoE math curriculum, new program phased from תשפ"ה; strands; milestones per grade (C: 6).
- Hebrew language and literacy curriculum; niqqud reduction from mid grade 3; morphology; "צומחים מחדש" (C: 7, 8).
- Academy of the Hebrew Language spelling rules 2017; grammatical spelling for vocalized text (C: 11).
- Israeli English Curriculum 2020: CEFR mapping, Pre-Foundation/Foundation timing, Lexical Pre-Band I/Band I, phonics (C: 9, 10).
- Science and technology curriculum 2016 with per-grade specs (S: 12).
- RAMA national tests and Pop task banks (S: 13, 6).
- Learning science: retrieval practice in children, guided retrieval, spacing after forgetting (C: 18); formative feedback (C: 19);
  four pillars of educational apps (C: 21); UDL 3.0 (C: 22); motivation/overjustification (S: 25).
- Item writing: Haladyna-Downing-Rodriguez 31 guidelines; distractor research; diagnostic questions (C: 20, 26).
- Accessibility: IS 5568 = WCAG 2.0 AA; WCAG 2.2 target size; dyslexia style; bidi isolation (C: 15, 16, 27, 28).
- Privacy and safety: Amendment 13; COPPA amended; ICO nudge standard; MoE AI guidelines (C: 14, 17, 29, 30).
- Inclusion: MoE gender editing of textbooks; Academy position on slash/dot forms (C: 31, 11b).

**Skills.** Item and distractor writing from misconceptions; elaborated feedback writing; leveling text; Hebrew
niqqud and spelling; EFL vocabulary leveling; fact verification and source triage; content review with rubric;
editing structured data safely (C/N as above).

**Tools and technology.** Web research; JSON/JS data editing; Git awareness (J9, niche); authoring tools such as
Storyline/Rise/Captivate (J4, J14, J15: core in postings but out of scope here); GenAI tools with human review (C: J5, J10, J15, 23).
Dicta Nakdan for niqqud verification (N: 32).

**Judgment and quality bar.** One skill per item; every wrong option diagnostic (26); feedback non-evaluative,
specific, task-focused (19); learning goal explicit, active/engaged/meaningful (21); EdReports-style focus,
coherence, rigor, usability lens for reviews (S: 33); fact verified twice; leveled language.

**Seniority signals.** Edits and mentors others (J18, J9 editorial reviewer); uses child data and psychometrics (J9);
maps coverage and gaps (J9); designs for accessibility from the start (J1, J18); uses AI while keeping human verification (23).

**Common mistakes / red flags.** Implausible or joke distractors, cueing, "all/none of the above" (20); feedback that judges
the child (19); distracting enhancements (21); unverified AI-generated content and hallucinations (23); niqqud errors;
gendered address and stereotypes (31); extrinsic rewards replacing learning (25); ASCII quotes and bidi reordering (28).

**Ethical, legal, safety limits.** No collection of children's personal data (14, 17); no manipulative nudges (29); no
generative AI for grades 1-3 (30); escalate official compliance, special-needs and legal questions to humans.

## 6. Embed / tool / human / out-of-scope mapping

| Competency | Decision | Notes |
|---|---|---|
| Item writing, distractors, feedback | Embed | rules in prompt |
| Curriculum alignment and leveling | Embed + Tool (web) | verify grade placements on Pop |
| Fact verification | Tool (WebSearch/WebFetch) | two sources per fact |
| Niqqud and spelling | Embed + Human-in-the-loop | flag uncertain words; Nakdan cross-check; language editor before publication |
| Review rubric and severity | Embed | output format |
| Editing content data in game files | Tool (Read/Edit/Write/Grep/Glob) | content only |
| Syntax validation of edited files | Tool (Bash, restricted) | `node --check` in scratchpad only |
| Accessibility, UDL, inclusion, privacy | Embed | report UI items to game designer |
| Mechanics/UI/code fixes | Out of scope (delegate) | senior-game-designer |
| Authoring tools (Storyline, Captivate, LMS) | Out of scope | not used by single-file HTML games |
| Testing items with children | Human-in-the-loop | agent proposes what to observe |
| Teaching license, degree, years | Out of scope | human credentials |
| Official curriculum approval, legal/privacy sign-off, diagnosis of learning difficulties | Human-in-the-loop | escalation section |

## 7. Contradictions and caveats

- Experience bar varies widely: 1 yr (J12) to 5-10 yrs (J18); teaching experience mandatory in some (J8, J13), not others (J9).
- Retrieval practice with children: mostly positive, but some studies show no advantage over re-reading and free recall is hard for children (18).
- Rewards and motivation: undermining effect contested; 2022 study found it only for games with high initial interest (25).
- "None of the above": "use carefully" (2002 review) vs later "avoid" (20). The agent avoids it for children.
- Gender: MoE requires gender editing (31), but some MoE documents still use masculine as generic; the Academy opposes slash/dot forms (11b). Agent uses plural imperative/neutral forms.
- Accessibility: Israeli binding reference is WCAG 2.0 AA (IS 5568), vendors often cite 2.1/2.2 (15). Agent cites 2.0 AA as legal floor, 2.2 target size as best practice.
- Math curriculum transition: grade entry year differs slightly across MoE pages (6). Agent must check.
- English in grades 1-2: 2023 cancellation of expansion vs 2025 MoE review listing ENJOY ENGLISH continuing (9b).
- RAMA structure: Wikipedia's grade 5 description is outdated vs rama.gov.il (13).
- ESCO: e-learning developer page shows inconsistent ISCO code (2356 vs 2359) (2).
- Niqqud spelling convention: Academy says vocalized = grammatical spelling (11); commercial kids' materials sometimes mix. Agent states convention and flags.

## 8. Sources (accessed 2026-11-27 unless noted)

Job postings: J1-J18 above, URLs:
- J1 https://careers.mheducation.com/jobs/4964?lang=en-us ; https://www.teamedforlearning.com/job-post/senior-instructional-designer-science-mcgraw-hill/
- J2 https://www.edtech.com/jobs/instructional-design-jobs (listing summary, 2026-10-19)
- J3 https://accessdubuquejobs.com/job/senior-academic-designer-literacy-grades-3-6-2/ ; https://www.edtech.com/jobs/senior-academic-designer-literacyprimary-grades-8459
- J4 https://hutchinsonkansasnewspaper.net/k12-inc-senior-instructional-designer-curriculum-development-educational-innovation
- J5 https://www.edtech.com/jobs/k-5-math-curriculum-writer-apriljune-2026-start-3326
- J6 https://listiller.com/k-5-math-content-writer-2/ ; https://www.virtualvocations.com/job/k-5-math-curriculum-writer-3178747-i.html
- J7 https://www.topschooljobs.org/job/2496916/elementary-school-math-curriculum-writer-consultant/
- J8 https://www.edtech.com/jobs/math-curriculum-writer-grades-3-5-3389 ; https://trulyhired.com/jobs/?categories%5B%5D=Curriculum&city=Boston
- J9 https://job-boards.greenhouse.io/khanacademy/jobs/8204881 ; https://himalayas.app/companies/khan-academy/jobs/bilingual-content-creator-khan-academy-kids-24-months-fixed-term
- J10 https://jobs.lever.co/kiddom/8ed4bda1-6ab8-4530-83c4-206673a9d963 ; https://builtin.com/job/instructional-designer-math/7939377
- J11 https://jobgether.com/offer/6a00c0c98444a8266554b8eb-math-and-professional-learning-content-writer-grades-5-12
- J12 https://drawerrr.com/jobs/content-designer-k-5-math-1644907355421
- J13 https://education.biu.ac.il/node/11322 ; https://www.levinsky.ac.il/notice/89951/
- J14 https://freehire.me/jobs/mpth-t-lmydh-center-for-educational-technology-guip4zoq ; https://cet.ac.il/career/
- J15 https://www.amarel.net/careers1/ (מעצב.ת חווית למידה) ; https://www.hit.ac.il/telem-jobs/ ; https://jobify360.co.il/jobs/2604708-jk
- J16 https://il.linkedin.com/jobs/mathematics-jobs (Matific listing) ; https://www.timesofisrael.com/israels-matific-raises-45m-to-expand-math-games/
- J17 https://www.alljobs.co.il/Search/UploadSingle.aspx?JobID=7862582
- J18 https://www.virtualvocations.com/job/senior-instructional-designer-3288951-i.html

Standards, curriculum, law, research:
1. O*NET OnLine, 25-9031.00 Instructional Coordinators (25-9031.01 Instructional Designers and Technologists retired). https://www.onetonline.org/link/summary/25-9031.00
2. ESCO, e-learning developer occupation page (ISCO 2356/2359 inconsistency). https://esco.ec.europa.eu/ga/classification/occupation?uri=http%3A%2F%2Fdata.europa.eu%2Fesco%2Foccupation%2Fec5b72d1-0206-4179-9abd-570c66bc44b9 ; ESCO skill "apply teaching strategies".
3. ATD, APTD (3+ yrs) and CPTD (5+ yrs) credentials, Capability Model. https://www.td.org/atd-resources/instructional-design/certification
4. ISTE+ASCD professional credentials. https://iste.org/professional-credentials
5. Cathy Moore, action mapping; "What is an instructional designer" (2026). https://blog.cathy-moore.com/what-is-an-instructional-designer/
6. Israeli MoE, Pop: new elementary math curriculum (phased from תשפ"ה), curriculum page, assessment task bank. https://pop.education.gov.il/tchumey_daat/matmatika/yesodi/oraat-math/new-curriculum/ ; https://pop.education.gov.il/tchumey_daat/matmatika/yesodi/oraat-math/assessment-tasks/
7. MoE Hebrew supervision, mafmar 2025 (niqqud reduction from mid grade 3). https://meyda.education.gov.il/files/Pop/0files/ivrit_hinuch_leshoni/Yesodi/mafmar-2025.pdf ; "מגמות בהוראת העברית" https://meyda.education.gov.il/files/Mazkirut_Pedagogit/HebrewPrimary/mafmardesk/mancal.pdf
8. MoE, "צומחים מחדש" grades 2-3, תשפ"ו. https://meyda.education.gov.il/files/Pop/0files/ivrit_hinuch_leshoni/Yesodi/growing-again-2-3g.pdf ; language and literacy curriculum https://meyda.education.gov.il/files/Pop/0files/ivrit_hinuch_leshoni/Yesodi/tohnit-limudim-safa.pdf
9. MoE, English Curriculum 2020 and elementary version; Revised Curriculum 2018. https://meyda.education.gov.il/files/Mazkirut_Pedagogit/English/Curriculum2020.pdf ; https://meyda.education.gov.il/files/Mazkirut_Pedagogit/English/curriculum2020Elementary.pdf ; https://meyda.education.gov.il/files/Mazkirut_Pedagogit/English/Curriculum2018July.pdf
9b. Knesset research/MoE review of English teaching, 2025-02-19 (ENJOY ENGLISH K-2). https://fs.knesset.gov.il/25/Committees/25_cs_bg_5723711.pdf ; TheMarker 2023-07-16 (expansion cancelled).
10. MoE, Lexical Pre-Band I and Band I (elementary); Foundation Level Lexis (1,200 items). https://meyda.education.gov.il/files/Mazkirut_Pedagogit/English/CurriculumFilesAugust21/LexicalBand1.pdf ; https://meyda.education.gov.il/files/Mazkirut_Pedagogit/English/band11July18.pdf
11. Academy of the Hebrew Language, full-spelling rules 2017 (updated Oct 2017). https://hebrew-academy.org.il/wp-content/uploads/klalei-haktiv-2017.pdf
11b. Academy position on slash/dot gender forms (press coverage). https://www.maariv.co.il/news/israel/article-1022344
12. MoE, science and technology curriculum grades 1-6 (2016) with grade specs for תשפ"ז. https://pop.education.gov.il/tchumey_daat/mada-tehnologia/yesodi/technology-science-pedagogy/curriculum/
13. RAMA, this year's assessments and Meitzav/Tnufa FAQ. https://rama.gov.il/questions/this-year-assessments ; Haaretz 2026-11-25 on Meitzav.
14. Israeli Privacy Protection Authority, professional guide to Amendment 13 (in force 2025-08-14). https://www.gov.il/he/pages/guide_tikon13_professional
15. IS 5568 / WCAG 2.0 AA and Equal Rights accessibility regulations 2013 (secondary guides, 2026). https://velolinx.co.il/blog/website-accessibility-israel-law-2026/
16. W3C, WCAG 2.2 Understanding SC 2.5.8 Target Size (Minimum). https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum
17. COPPA amended rule: effective 2025-06-23, compliance 2026-04-22. https://www.hunton.com/privacy-and-cybersecurity-law-blog/coppa-rule-amendment-compliance-deadline-approaches
18. Fazio and Marsh 2019, Retrieval-Based Learning in Children (Current Directions in Psych. Science); systematic review of retrieval practice with children; Karpicke et al. 2014 guided retrieval; Lipowski et al. elementary retrieval. https://journals.sagepub.com/doi/10.1177/0963721418806673 ; https://revistas.urosario.edu.co/xml/799/79971087011/html/index.html ; https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4786565/
19. Shute 2008, Focus on Formative Feedback, Review of Educational Research. https://myweb.fsu.edu/vshute/pdf/shute%202008_b.pdf
20. Haladyna, Downing and Rodriguez 2002, review of MC item-writing guidelines; Gierl et al. 2017 RER on distractors. https://site.ufvjm.edu.br/fammuc/files/2016/05/item-writing-guidelines.pdf ; https://tipsforteachers.co.uk/wp-content/uploads/2025/06/Research-Developing-Analyzing-and-Using-Distractors-for-Multiple-Choice-Tests-in-Education.pdf
21. Hirsh-Pasek et al. 2015, Putting Education in "Educational" Apps, PSPI 16(1). https://www.psychologicalscience.org/publications/educational-apps.html
22. CAST, UDL Guidelines 3.0 (2024) summary of changes. https://www.cast.org/binaries/content/assets/cast/downloads/cast-udlg3-summaryofchanges-onepage-a11y.pdf
23. GenAI in instructional design systematic review (2026, Computers 15(11)); K-12 GenAI systematic review; "Judging the Judges" human validation of LLM evaluation of K-12 science materials (2026); OECD Digital Education Outlook 2026. https://doi.org/10.3390/computers15110745 ; https://arxiv.org/pdf/2602.13243 ; https://www.oecd.org/content/dam/oecd/en/publications/reports/2026/01/oecd-digital-education-outlook-2026_940e0dd8/062a7394-en.pdf
24. EdReports and Common Core usage in postings (accuracy and SME review norms) - see J6, J9, J10.
25. Rewards and children's motivation in video games (Springer 2022); Giessen review of rewards in gamification. https://link.springer.com/article/10.1007/s12144-022-02905-6
26. Eedi / Craig Barton, What makes a good diagnostic question; Eedi 4M responses analysis; Eedi-Anthropic collaboration. https://medium.com/eedi/what-makes-a-good-diagnostic-question-b760a65e0320 ; https://eedi.substack.com/p/what-do-4-million-students-responses ; https://www.eedi.com/news/on-our-collaboration-with-anthropic-and-why-were-bringing-diagnostic-questions-to-claude-for-teachers
27. British Dyslexia Association, Dyslexia Style Guide 2023 / creating dyslexia-friendly resources. https://www.bdadyslexia.org.uk/advice/educators/teaching-for-neurodiversity/creating-dyslexia-friendly-resources
28. W3C Internationalization, Inline markup and bidirectional text in HTML; bidi Unicode controls. https://w3.org/International/articles/inline-bidi-markup/index.en.html ; https://www.w3.org/International/questions/qa-bidi-unicode-controls
29. UK ICO, Age Appropriate Design Code, standard 13 nudge techniques (under review after DUAA). https://ico.org.uk/for-organisations/advice-and-services/audits/data-protection-audit-framework/toolkits/age-appropriate-design/nudge-techniques/
30. Israeli MoE, AI usage guidelines (published 2025-01-20; summary updated Jan 2026): no GenAI tools grades 1-3; grade 4 MoE bot only with parental consent; grades 5-7 catalog tools under teacher supervision. https://meyda.education.gov.il/files/Pop/0files/lemida-metukshevet/AI/AI-Usage-Guidelines.pdf
31. MoE, gender editing as a condition for textbook approval (2019 letter); 2010 criteria (Knesset doc). https://meyda.education.gov.il/files/yesodi/hachala/hishtalvot/rakaz11.pdf ; https://fs.knesset.gov.il/globaldocs/MMM/6d19fd4f-8a82-e811-80de-00155d0a0b8d/2_6d19fd4f-8a82-e811-80de-00155d0a0b8d_11_12387.pdf
32. Dicta, Nakdan: Professional Hebrew Diacritizer (ACL 2020). https://aclanthology.org/2020.acl-demos.23
33. EdReports, Math K-8 Review Criteria 2.0 (gateways: focus and coherence, rigor and practices, usability). https://cdn.edreports.org/media/2026/06/Math%20K-8%20Review%20Criteria_2.0.pdf

Source count: 18 job postings (15+ employers, 5 Israeli) + 33 standards/curriculum/law/research/practitioner/trend sources.

## 9. Quality-gate run (mental tests)

1. "Write 10 animal trivia questions, easy level, in the trivia game's format" -> frame (grades 1-3, full niqqud), item specs,
   facts verified twice (myth check), 2-3 options, plural-imperative feedback, ready-to-paste array, niqqud flags. Covered.
2. "Review מסע החשבון for grade 2" -> align to new math curriculum (grade 2 since תשפ"ו; verify), check number agreement,
   bidi of expressions (hand to game designer), distractors from regrouping errors, motivation and timers, scored table. Covered.
3. "Add 30 Band I words to Flip & Learn for grade 4" -> Lexical Pre-Band I/Band I lists, Hebrew translation leveled by grade
   (niqqud reduced from mid grade 3), LTR isolation, edit data only, node --check, counts. Covered.
   Gap found and fixed during the run: RAMA claims softened to what sources support; English start grade marked "verify".
