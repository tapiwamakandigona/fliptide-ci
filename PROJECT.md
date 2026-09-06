# PROJECT.md — Fliptide (was working title "FLIP")

<!-- The resume point for any fresh agent. Keep it current; keep it short.
     Template: subagent-toolkit v3.0.1 templates/PROJECT.md -->

## Goal

A one-tap gravity-flip precision runner that produces its own content: every
death yields a shareable text card + course code, every UTC day yields the same
course for everyone. Done for phase 1 = a stranger can open the Pages build on a
phone or Chromebook, understand it in 3 seconds, play to a death, and paste a
share text into WhatsApp that a friend can use to play the same course. Done
overall = `1.0.0` live on Google Play under the Tsoro Studios account with the
Supporter IAP working, and a CrazyGames listing feeding it players.

## Session-start ritual

1. Read this file, `features.json`, `DEMAND.md` (top directive first), and the
   tail of `progress.md`.
2. Run `flutter test` and confirm the baseline is green (record the count).
3. Pick the single most important unfinished feature in `features.json`; work
   only on that. Flip `passes` to true only with evidence in `evidence`.

## Standing decisions

- Name is **Fliptide**; applicationId `com.tsorostudios.fliptide`; repos
  `fliptide` (private) / `fliptide-ci` (public mirror). "FLIP" survives only in
  history. Checked 2026-09-02: no exact match on Play or itch, 2 unrelated
  GitHub repos, fliptide.me/.games/.app unregistered. (2026-09-02, lead)
- **Google Play is the primary money surface.** The owner's Play merchant
  account is working and is the easiest way to collect money from Zimbabwe
  (owner, 2026-09-02). Supporter IAP via Play Billing is built BEFORE any ad
  code. Ads are gated on the owner side verifying an AdMob payout path to
  Zimbabwe; until then, ad slots exist in design only. (2026-09-02, lead)
- **Web = acquisition + measurement, not revenue** for now. CrazyGames Basic
  Launch (no SDK, free, non-exclusive) is moved INTO phase 1 because it is the
  only free source of playtime numbers for the phase-1 gate. Poki stays a
  phase-4 option. (2026-09-02, lead)
- **Web payload bar = per-player transfer**: "≤6 MB gz" means what one player downloads to first frame on each renderer path (skwasm for Chromium ≥119; full CanvasKit + JS for the rest), not the zip on disk. PR #1 numbers 2.32 / 4.12 MB gz PASS as-is; do not subset Inter, do not drop skwasm. (2026-09-02, owner 02j-1)
- Engine stays Flutter + Flame: Pages gz transfer measured 3.5 MB (canvaskit)
  → inside the 6 MB budget; `--wasm` build in CI. Re-measure every release.
  (2026-09-02, builder measurement)
- Daily courses must be reproducible forever: generator version + chunk set are
  part of the course code; adding chunks never changes an already-issued code.
  (2026-09-02, lead — from the builder's own note)
- Fleet rules from DEMAND directives 2026-09-02d/e stand: gates are the
  owner's call; no builder attribution on public surfaces; never regenerate
  the key; one runner.

## Constraints

- No spend without the owner: no domains, no paid assets, no ad spend.
- No analytics SDK beyond what AdMob requires; privacy policy published on the
  public Pages before any store submission.
- 100 % original art/audio; OFL fonts credited. No third-party memes.
- Web bundle ≤ 6 MB gz, first playable frame ≤ 5 s @ 10 Mbps; Android cold
  start ≤ 2 s; restart ≤ 300 ms. Measured, in `progress.md`.
- Flutter 3.44.9 pinned (do not drift the toolchain mid-phase).
- Owner is travelling mid-September 2026; phase-1 gate numbers are wanted
  before then.

## Structure (2026-09-06)

The game has three ways in, all from the title screen: **The Tides** (5 tides ×
6 authored courses, stars, unlocks — `lib/sim/campaign.dart`), the **Daily**
(same seeded course for everyone, streaks), and **Course codes** (shared
links). Campaign courses are frozen `GenSpec`s: change a seed and you change
that course for every player — treat them as content, never renumber ids.

## Current phase

build — phase 1 (pillars / blockout) per DEMAND §6, with the phase-1
definition of done in `features.json`. Stop at the gate; write the numbers.

Status 2026-09-02 13:1xZ (main frozen at the CG package; Pages + /privacy/ live):
phase 1 numbers stand (features.json F1 F2 F4 F5 F6 F8 F9 F10 pass; F3 web 165 ms
median; F7 lead playthrough done, Discord playtest owner-side). CrazyGames review
stalled on their payee onboarding → Google Play is the first money surface (02O).
Phase 2 built on `next/android-ads` (3230a2c) = **PR #2** "phase 2: ads + supporter
IAP (merge after Play internal test)": AdMob per 02k + Supporter IAP
`fliptide_supporter` $1.99 per 02O, 96 tests, analyze clean, web 0 third-party;
signed AAB from mirror run 33632314186 (sha c2c3faac…fdb22, BILLING +
APPLICATION_ID present, ~10.6 MB per-device). `next/payload-trim` c1d530d = PR #1
(merge after "CG approved"). Emulator smoke = needs device (02O-5). History
re-authored 2026-09-02 (02L/02N): all refs in the owner's name.
AT THE GATE (phase 2 → Play internal test), permitted work only. Waiting on:
Play app + internal-testing upload and `fliptide_supporter` live in the Console
(then a real test purchase on the owner's device), "CG approved" (merge PR #1,
repackage CG zip), or "cut vX.Y.Z" (scripts/cut_release.sh).
Status 2026-09-02 12:3xZ (HEAD 970b4fb on main, CI green @415c2ec mirror, Pages +
privacy live): features.json F1 F2 F4 F5 F6 F8 F9 F10 pass with evidence (main: 71
tests, analyze clean). F3 = web measured (median 165 ms, guard 150 ms → worst ≈230 ms);
Android run is owner-side (02g). F7 = lead desktop playthrough done (02h defects fixed
in 198a1d6); owner phone run + Discord playtest pending. CrazyGames zip cd17206
(sha a0b99dd2…) uploaded by the owner, awaiting CG review — main frozen until
"CG approved" (02i). Branches: `next/payload-trim` c1d530d = PR #1 (payload prune +
won-screen sprite fade, merge after CG approval); `next/android-ads` 535e822 = AdMob
per 02k (85 tests, web 0 third-party; emulator smoke outstanding — owner has the
arm64 debug APK). History re-authored 2026-09-02 (02L/02N): all refs in the owner's
name. AT THE GATE — permitted work only. Waiting on: "smoke OK", "CG approved",
"gate pass" (phase 2: Play Billing → merge ads branch), or "cut vX.Y.Z"
(scripts/cut_release.sh).

## Scoped maintenance task — 2026-09-05

Plan: reproduce the startup Supporter/ad-load race with a new regression file, then
fix only the asynchronous startup guard. Work on an isolated branch based on
`next/android-ads`; main, CrazyGames package, Pages game bytes, signing keys, and
existing tests/acceptance criteria remain untouched.

Verification: existing Flutter 3.44.9 public-mirror PR CI (analyze + all tests;
Android/Pages jobs skipped for pull requests). First run must demonstrate the
regression on unchanged app code; one source fix/retest follows. No local Flutter
result or real purchase is claimed. F3/F7 remain owner-device/human gates.

VERIFIED result: red run 33946144377 (97 passed, 2 new regressions failed) →
source-only guard → green run 33946239735 (analyzer clean, 99 passed). F11 passes;
F3/F7 stay false. Review/merge this maintenance change into `next/android-ads` only,
never interpret it as permission to merge PR #2 into frozen main or release.

## Scoped gameplay improvement — 2026-09-05

User requested further game improvements. This iteration addresses one observed
interaction defect: CODE opens a modal over a still-running attempt. Pause only
for the modal; Cancel/invalid input resume the same attempt; valid navigation or
screen disposal leave the abandoned game stopped; preserve a pre-existing pause.
No physics, course generation, visual design, monetization rules, or existing
tests/acceptance criteria change. F12 stays false until evidence exists.

Test-first plan: add five widget regressions on the public mirror, observe the
failures against unchanged application code, then apply one source fix and rerun
the full existing analyze/test CI. Local Flutter remains unavailable. Leave this
stacked branch reviewable and unmerged; main/Pages/CrazyGames package stay frozen.

CI routing VERIFIED: owner-requested public-only CI. Private workflow IDs
348116910 and 348320692 are disabled_manually; public-mirror workflows remain
active. The managed integration could not change workflow settings (HTTP 403);
the supplied owner token had admin permission and returned HTTP 204 for both
disables; final states reread from the GitHub API. No payment/limit change.

VERIFIED result: public red run 33947097217 (100 pass / 4 new failures) →
source-only fix 51fccda → green run 33947233407 (analyzer clean, 104 pass).
All five new cases pass without modifying the regression file; 51 private
application/test/dependency/workflow files match the tested public commit.
F12 now passes; F3/F7 and phase gates remain open. CI routing runbook:
`docs/public-ci.md`. No paid runner, release build, or deployment.
