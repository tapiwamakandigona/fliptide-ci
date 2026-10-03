# Fliptide — gauntlet plan (what the world should be)

Phases + gates are in DEMAND.md §6. This is the build map.

## Architecture
- `lib/sim/` — pure Dart, no Flutter imports. `course.dart` (columns/chunks), `chunks.dart`
  (authored library), `physics.dart` (fixed 120 Hz step, replay), `solver.dart` (BFS over
  grounded frames), `generator.dart` (seeded course + daily seed).
- `lib/game/` — Flame `FlipGame`: renders the sim, camera follows x, interpolates between
  sim steps, draws corridor/blocks/spikes/player/ghost/death marker, particles.
- `lib/ui/` — Flutter overlays: title, HUD, death card, share card (RepaintBoundary → PNG).
- `lib/store/` — shared_preferences: best % per daily, attempts, streak, ghost replay.
- `tool/` — designer aids (`try_chunk.dart`), later: clip cutter, screenshot script.

## Phase 1 (blockout) checklist
- [x] sim + solver + generator + tests
- [ ] Flame renderer, tap/click/space input, restart <300 ms
- [ ] HUD: %, attempts, daily #
- [ ] death overlay: %, attempt, Retry, Share
- [ ] share card PNG (course map + X + attempts + name), web download
- [ ] ghost of best run
- [ ] web build on Pages; phone + desktop screenshots read
- [ ] Poki playtest ask → owner (needs dev account)

## Phase 2 (playable) — starts only on owner's "gate pass"
Order (per DEMAND 02e/02f): 1) Supporter IAP $1.99 via Play Billing (no ads + all skins),
then publish /privacy.html naming Play Billing (+ AdMob only once ad code exists);
2) 15 campaign levels (authored chunk sequences, speed ramps 8→11) with "stay on one side"
chunk variants (KP-3); 3) practice checkpoints; 4) Daily streaks; 5) portrait band use (KP-2);
6) ads LAST and only after owner confirms AdMob payout to Zimbabwe — cadence rule DEMAND §3
(never inside an attempt, never in first 3 min of fresh install, ≥90 s between interstitials,
death count is NOT a trigger; rewarded = skins/ghost hints only). Signed release on
fliptide-ci via scripts/cut_release.sh on owner's "cut".

## Phase 3 (dressing)
≥6 original creature skins (code-drawn), death-clip export, synth soundtrack (numpy
pipeline from Pyregrove `tool/build_original_music.py` pattern), store listing, Shorts
clip-cutting script.

## Phase 4 (polish/launch)
CrazyGames Basic Launch → Play internal → production; Poki review; level editor + share codes.
