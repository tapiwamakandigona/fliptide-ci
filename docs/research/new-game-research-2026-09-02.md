# New mobile game — research brief (2026-09-01/02)

User shortlist (own words, 2026-09-01): fruit merge (Suika), snake (.io), hole game, screw.
Baseline to beat: Emberdelve cold Play launch ≈ 38 installs (docs/CHANNEL-RECEIPTS.md).

## Market receipts (VERIFIED via web search, dated)
- Median mobile retention D1 ~22% / D7 ~4% / D30 ~0.7–3.5% [GameAnalytics 2025, GGA 2026-03].
- All in Hole D1 56.7% (best hybrid-casual); Block Blast D1 53.5/D7 33.4/D30 21.7 [Sensor Tower Jan-26 cohort].
- Sort/Screw/Block ≈ $600M IAP H1'26; Screw Jam $25M (2024), Screwdom $75M+ (2025) [AppMagic, DoF 2026-02].
- Hole: All in Hole $130M IAP; ~120 hole games 2025–26; Homa/Supersonic/Moon Active UA war [Gamigion 2026-08].
- Suika: original 11M+ DLs (Switch/streamer wave 2023–24). Clones: QS Monkey Land 10M+ installs, ~$10K+/mo;
  Fruit Merge-Juicy Melon 5M installs, ~$10K+/mo [AppGoblin 2026]. Official Android $1.99 paid, 443K, 3.86★.
  Solo browser Fruit Merge (Kento Morishima): ~3 months build, physics tuning = most of the time.
- Snake .io: Snake Clash 182M installs, 4M DL/mo (paid UA, 185 ad creatives, AI ads), $80–500K/mo est.
  Per-user monetization is dreadful: Snake.io ~1M US actives → ~$3.6K/WEEK; Snake Clash 1.35M → $12.5K/wk
  [Sensor Tower Q4'25]. slither.io 719K actives 8 yrs on.
- **Snake PUZZLE (Gecko Out, Rollic): $249K/WEEK on 148K US actives** — ~100x per-user vs .io snake
  [Sensor Tower Q4'25]. Wiggle Escape (Paxie, Oct-25): 3.1M installs/9 mo, 4.64★. Level-content treadmill.
- Daily/seeded formats: Proximath 53% D2 (browser, built in an evening); Sphinx Riddle 1,000 users at $0 via
  TikTok carousels; Wordling (TapNation) daily+share hybrid-casual [2025–26].

## Distribution finding: web portals (the differ-test answer)
- Poki: 100M MAU, 1B plays/mo, 600 partners; first web game realistically $500–3,000/mo (Poki devrel);
  top studios $1M/yr. Split 50/50 on Poki traffic, 100% on traffic you bring. Free. Pipeline: 10 playtest
  recordings → player-fit test (500 players, ~5h, 2/day; bar 3+ min avg, 25% >3 min) → web-fit (7 days,
  target 65%+ C2P; avg game 70% / 6+ min) → review 1–2 wks. Needs: 16:9 scaling, portrait on mobile,
  <10s load, Poki SDK, incognito-safe, playable with adblock [developers.poki.com 2026].
- CrazyGames: 50M+ MAU, self-serve, QA 1–2 days, Basic Launch (no SDK, measures) → Full Launch (SDK, earns);
  60% ads / 70% IAP (2026 jam terms); €100 min payout; non-exclusive OK. Solo receipts: €31/day novel
  roguelite (exclusivity deal boosted visibility); $400 lifetime for a simple Construct game [2026].
- Web-game money median: $200–2,000/mo for a well-performing casual game on a major portal [Cinevva 2026-07].

## Engine note
Poki principal eng: "every extra MB loses a couple % of players"; web-native (Phaser/PixiJS/PlayCanvas/
Construct) preferred; Unity/Godot = wasm blob. Flutter web = CanvasKit blob (~2–4MB+ first load), `--wasm`
flaky [Wavedash docs 2026]. Flame is OK for CrazyGames (50MB limit), marginal for Poki. ASSUMED: Phaser
web-first + TWA/Capacitor wrap for Play is viable — ad SDK inside TWA unverified.

## Verdict as delivered 2026-09-02
Web-first (CrazyGames → Poki) then Play. Mechanic fit for portals = long sessions + instant readability +
tiny load: Suika (+daily seed/share twist) or .io snake (bots). Hole/screw = UA-driven, skip for solo/$0.
Snake-puzzle = best Play monetization receipt but content treadmill + Rollic incumbent.

## Round 3 (2026-09-02): US kids/teens, Play-first, $0 marketing — receipts
User: "only way I make money is Play Store"; Emberdelve had 2 US purchases (NJ, PA) on ~38 installs.
- Who plays what: Roblox = 62% of US 10–12yo, 143 min/day [Qustodio 2024/25]; 85% of US teens game, 70% on
  phone [Pew 2024]. Gen Z favorites 2026: Fortnite, Roblox, Minecraft, CoD, Subway Surfers, Candy Crush,
  Clash (M), Sims (F) [YPulse 2026-05]. Block Blast 175M DLs H1'26, $127M ad rev Jan–May 26, D1 53.5 [ST].
- **US teens PAY for premium**: Play top-paid US 2026-08: Minecraft $6.99 (97M), Geometry Dash $1.99
  (12M, 4.8★, 130K recent), Bloons TD6, Papa's Freezeria To Go $0.99, FNAF [AppBrain 2026-08-31].
- Kids (<13) money = 100% IAP, no ads: Avatar World (Pazu) 260M installs, $500K+/mo, 0% ads [AppGoblin];
  Toca Boca World 440M. Families policy: certified ad SDKs only, non-personalized → smaller ad pool.
- **Meme/trend riding on Play search**: Sprunki Beat (Gotstar) 37.9M installs, ~$200K+/mo, 458K/wk still;
  Steal a Brainrot clone (Mashal Soft, PK) 3.9M installs ~$10K+/mo; Merge Fellas +2.1M installs Mar–Jun 25
  from brainrot update, 62% US [FoxData]; Rafael Kramer (age 14) DaBaby meme game 2M DLs/$100K profit in a
  month. Risks: Incredibox C&D (Cocrea), ShinStar suing Sprunki counterfeits; trends rotate in months
  (Steal an Egg > Steal a Brainrot Aug-26). Play ranking: title = heaviest metadata, install velocity =
  heaviest signal [vmobify 2026-05].
- **Content-template games**: Block Blast "distribution win not design win" — fails/near-wins ARE TikTok
  content; Splashin (Senior Assassin app) $1M MRR, users create the marketing; 38-0-0 2M users wk 1;
  onlypancak3s 18M Shorts views → 28K wishlists (hook about viewer, ~40s, pinned comment CTA).
  Counter-receipt: 5.7M Shorts views → 500 installs (0.01%) when game isn't a template.
- **School Chromebook web**: unblocked-games sites ("over half traffic from school Chromebooks") accept
  HTML5 by email weekly (contact@unblockedgames76.school); Steal a Brainrot on Poki 400K ratings.
- Gen Alpha design cues (Tanghulu Master #1 KR): cute detailed characters, ASMR, player-as-creator.
