# DEMAND — Fliptide (was working title "FLIP")

What "good" means for every session on this project. Edited only when standards
genuinely change. Never contains diagnosis of the current build — that lives in
`progress.md`.

**Owner:** Tapiwa Makandigona (Tsoro Studios). **Builder:** the Tsoro Studios build pipeline
(single agent). The owner edits this file to redirect the work. The builder
re-reads it (`git pull` + full read) at every cold start and before every phase
gate, and acknowledges any new owner directive in `progress.md` with a timestamp
before doing anything else.

> Owner: to tell the builder what to do, add a dated `## Owner directive YYYY-MM-DD`
> section at the TOP of this file (newest first). Plain language is fine.

---

## Owner directive 2026-09-05a — main UNFROZEN for the polish pass; two agents, two lanes (2026-09-05 06:10Z)
The owner said in chat: "Fliptide could use some more work to look much neater and smoother" and then
"go ahead with what you recommend". Applied as follows:
1. **main is unfrozen for the render-only polish pass** (`polish-main`, fast-forwarded into main). Pages
   rebuilds from it. The CG package zip in docs/crazygames is NOT rebuilt; PR #1 ("CG approved") and
   PR #2 ("merge after Play internal test") keep their gates. PR #5 carries the same polish for
   `next/android-ads` so phase 2 does not lose it.
2. **Two agents are working this repo today.** Lane split so we do not collide: the ops/lead agent
   (this directive's author) owns `main`, Pages, Play Console, store docs and the polish/visual pass;
   the builder agent owns gameplay/ads/IAP fixes on the `next/android-ads` stack (PRs #3, #4).
   Before touching `lib/main.dart` or `lib/game/flip_game.dart`, rebase on the latest of your base
   branch — PR #5 and PR #3 both edit `lib/main.dart`.
3. Never `git pull`/merge across the lanes; rebase your own branch only. Log in progress.md as usual.
## Owner directive 2026-09-02O — GATE PASS for phase 2, on the branch (2026-09-02 12:45Z)
CrazyGames review is stalled on their side (payee onboarding), so Google Play is the first money surface. Do not wait for "CG approved" to build phase 2. Rules of 02i still hold: **main stays frozen** (no game code on main, no CG package rebuild, no Pages game-bundle change, no release, no merge). All of this lands on `next/android-ads` (rename is not needed).

1. **Supporter IAP** (`in_app_purchase`, Play Billing). Product id `fliptide_supporter`, non-consumable, USD 1.99. One "Support" entry point on the title screen + one line on the CLEARED card ("Remove ads · $1.99"), nothing on the death card. Purchase → `supporter=true` persisted (shared_preferences) → every ad load suppressed (you already honour the flag) → a small "Supporter" mark on the title screen. Restore purchases on startup (queryPastPurchases) and via a "Restore" text button in the same place. Web: stub, no UI. Debug: use the Play Billing test flow, never a fake purchase path in release code. Tests: flag persistence, ad-policy suppression after purchase, restore path, no purchase UI on web.
2. **Privacy page now, on the branch**: interstitial cap "one every 3 minutes, never between a death and the retry", list `com.android.vending.BILLING` as present (it will be). Same text in `docs/privacy/index.html`; republish to Pages only when I say — it is a docs file, so a Pages republish of docs/ alone is fine if it does not touch the game bundle.
3. **Signed AAB with ads + billing** from CI on this branch. Report: sha256, size, `aapt2` permission list, that `BILLING` and `APPLICATION_ID` are present. I will create the Play app and upload it to internal testing myself, then create the `fliptide_supporter` product in the Console and tell you when it is live so you can run a real test purchase flow on a device I provide later.
4. Flags from 02k, answered: (a) yes, IAP now — this directive; (b) correct, 02e's skins/hints wording is dead, second chance stands; (c) change the privacy text now as in item 2.
5. Emulator smoke: stop retrying in the sandbox; the ANR is the environment. Log it once as "needs device", move on. I will run the APK on a phone.
6. When items 1–3 are done, open **PR #2** "phase 2: ads + supporter IAP (merge after Play internal test)" from `next/android-ads` → `main`, and stop at the gate again with the AAB evidence in progress.md.
## Owner directive 2026-09-02N — History rewrite COMPLETE. Reset, verify, resume (2026-09-02 11:55Z)
Every branch and tag was rewritten; all commit SHAs changed. Your local clone/worktree is now on a dead history. Do exactly this:
1. `git fetch origin --prune --tags --force`
2. For every branch you track: `git checkout <branch> && git reset --hard origin/<branch>`  — **never** `git pull`/`git merge`; merging old and new history would resurrect the Viktor commits.
3. Re-apply your WIP from the patch/stash, commit as `Tapiwa Makandigona <tapiwamakandigoner@gmail.com>` (directive L), push normally.
4. Prove it in progress.md: `git log --format='%an <%ae>' | sort | uniq -c` must show only the owner, and `git status` clean.
Then resume the plan you were on.
## Owner directive 2026-09-02M — STOP PUSHING. History rewrite in progress (2026-09-02 11:50Z)
The owner approved re-authoring the entire history of this repo so every past commit is his. That is a force-push of
every branch and tag. Until a later directive titled "history rewrite COMPLETE" appears in this file:
1. If you have unpushed commits, push them **right now** (normal push, no force). After that: **no commits, no pushes, no tags.**
2. Keep working locally only if you must, but do NOT create commits — stash or keep a patch (`git diff > /tmp/wip.patch`).
3. Do not `git pull`, `git merge` or `git rebase` during this window.
Expected duration: under an hour. Re-read this file every few minutes.
## Owner directive 2026-09-02L — Author identity: everything in the owner's name, effective immediately (2026-09-02 11:30Z)
The owner has ruled: **every artifact in this repo is his.** No exceptions, no "assistant" identity.

1. Git identity for ALL future commits (both author and committer), tags and worktrees:
   `git config user.name "Tapiwa Makandigona"` and `git config user.email "tapiwamakandigoner@gmail.com"`.
   Set it in every clone/worktree you use for this repo *before* the next commit. Also unset any
   `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env overrides and any global config that says Viktor.
2. Never again use `Viktor`, `viktor@tsorostudios.dev`, `viktor@tsorostudios.invalid` or the
   `viktor+ws.…@users.noreply.github.com` address. Grep the repo (`git grep -in viktor`) and remove the
   word from every tracked file where it names an author, maintainer, contributor or "who did this"
   (README, CHANGELOG, progress.md, release notes templates, code headers, Play/CG listing docs).
   Progress-log entries stay factual but are written in first person as the owner ("I fixed…"), not as a third party.
3. Release notes, tags and GitHub Release bodies: no "generated by", "assistant", or agent attribution. They are the owner's release notes.
4. Confirm in progress.md with the output of `git log -1 --format='%an <%ae> | %cn <%ce>'` after your next commit
   and the result of `git grep -in viktor | wc -l` (must be 0 excluding this directive line itself in DEMAND.md).
5. Do NOT rewrite already-pushed history (no force-push) — the owner decides separately whether past commits get re-authored.
## Owner directive 2026-09-02k — AdMob is real now; wire it on a branch (2026-09-02 11:15Z)
The AdMob account, the Fliptide app entry and two ad units exist under the owner's publisher.
These identifiers are public by design (they ship inside every APK), so they belong in the repo:

- App ID (AndroidManifest `com.google.android.gms.ads.APPLICATION_ID`): `ca-app-pub-5182383335652302~6877765460`
- Rewarded — "second chance": `ca-app-pub-5182383335652302/2421796507`
- Interstitial — "session break": `ca-app-pub-5182383335652302/6829664002`

Branch `next/android-ads` off `next/payload-trim` (main stays frozen for CrazyGames). Rules, non-negotiable:
1. **Android only.** Web build stays at zero third-party requests; the ads plugin must not be linked into web (conditional import / platform check, proven by `verify_prune.py` still reporting 0 third-party).
2. **Die → restart stays <300 ms.** No ad may ever sit between death and the next attempt. The rewarded unit is an *opt-in button* on the death overlay ("Second chance — watch an ad, resume from the last checkpoint") shown at most once per Daily, never on attempt 1–2.
3. **Interstitial only at a real session break**: after CLEARED, or after the player backgrounds and returns, capped at 1 per 3 minutes and never within 60 s of app start. Nothing before the first tap of a session.
4. **Supporter IAP ($1.99) removes every ad**, persisted locally; the flag is checked before any load call.
5. **Debug/profile builds use Google's published test unit IDs; release uses the real ones.** Use `MobileAds.instance.requestConfiguration` with `tagForChildDirectedTreatment` unspecified and `maxAdContentRating = T` (Play 13+ audience; content rating doc already says so). Add the UMP consent form call at startup (required for EEA/UK; harmless elsewhere).
6. Update `docs/privacy/index.html` only if the actual SDK behaviour differs from what it already states (it names AdMob and Play Billing). The web build's "no ads" statement must stay true.
7. Evidence in progress.md: `flutter analyze` clean, tests green (63 + new ones for the ad gating: state machine says no ad on attempt 1–2, no ad within 300 ms of death, supporter flag suppresses loads), one APK smoke run on an emulator showing a test rewarded ad completing and resuming from the checkpoint. Do **not** cut a release, do **not** merge to main, do **not** touch the CG package.
8. Also add `app-ads.txt` handling note: the developer website will be https://tapiwa.me and the file there will read `google.com, pub-5182383335652302, DIRECT, f08c47fec0942fa0` — reference it in `docs/play-store/listing.md` (Developer website field).
Do the sprite-overlap fix from 02j first; then this.
## Owner directive 2026-09-02j — QA verdict on 02i (2026-09-02 10:55Z)
Reviewed: PR #1, `gh-pages-trim`, `docs/privacy/index.html` (live, 200), `docs/play-store/*`,
all 8 screenshots opened at full size. Good, fast work. Two rulings and one bug:

1. **Payload bar — ruling: PASS as-is.** The pillar "web ≤6 MB gz" was always about what one
   player downloads before first frame, not the zip on disk. Your numbers (2.32 MB gz Chromium,
   4.12 MB gz Safari/Firefox, both <4 s to first frame) clear it with room. Do **not** subset
   Inter (glyph risk on a game whose share text is user-visible), do **not** drop skwasm.
   Record the interpretation in `PROJECT.md` under standing decisions, one line, and add
   "per-player transfer ≤6 MB gz, both renderer paths" as the F-criterion wording in
   `features.json` — this is a clarification of the bar, not a loosening; evidence unchanged.
2. **PR #1 stays open** until "CG approved" appears in DEMAND.md. Unchanged.
3. **Bug (found in screenshot 8, `8-cleared.png`)**: on the CLEARED screen the player cube is
   drawn ON TOP of the "attempt 2 · tell someone" caption, overlapping the word "attempt".
   The won-screen overlay does not hide or fade the sprite. Fix on `next/payload-trim` (it is
   not in the CG package and must not be — main is frozen): on state `cleared`, either fade
   the player to 0 over ~150 ms before the caption appears, or park it at the checkered line.
   Check the same for the death screen (`6-death.png` is clean, keep it that way). Add a
   golden/widget test that asserts no player sprite pixels inside the caption rect on the won
   screen. Then **retake screenshot 8 only** from the fixed build, same seed, same device
   frame, and replace `docs/play-store/screens/8-cleared.png`. Evidence in progress.md.
4. After that: idle again, awaiting the lead's "CG approved" note. Nothing else.
## Owner directive 2026-09-02i — CrazyGames is staged; do NOT touch the uploaded build (2026-09-02 10:25Z)
Status from the lead: your `cd17206` zip (35 files, sha a0b99dd2…) is uploaded to CrazyGames,
renders in their QA tool, Details step is complete (Arcade; tags Running/Jumping/Platform/
Obstacle/Avoid; 3 covers; 2 preview videos). Final "Submit for approval" waits on an
owner-side billing step. **Rule: `main` stays exactly at the packaged commit until CG
approves — no rebuild of `docs/crazygames/fliptide-web.zip`, no Pages redeploy.** Work on a
branch `next/payload-trim` and land these, in order, each with evidence in progress.md:
1. **Payload trim (branch only).** The packaged web build ships ≈26 MB of assets nothing
   loads (canvaskit.wasm variants, `chromium/`, `skwasm_heavy`, unused fonts). Target
   ≤6 MB gzipped per the pillar. Use `flutter build web --wasm` with the renderer that
   Flame actually uses, drop the fallback renderers via `--no-web-resources-cdn` review /
   post-build prune script (`scripts/prune_web.sh`, lists what it deletes). Prove with
   `du -sh` before/after and a headless first-frame time on the pruned build served from a
   throwaway `gh-pages-trim` branch of fliptide-ci (NOT the live Pages root). Zero
   third-party requests must still hold. Do not merge to main; open a PR titled
   "payload trim (merge after CG approval)".
2. **Fliptide privacy page → live.** `docs/privacy/privacy.draft.html` becomes
   `docs/privacy/index.html` on the fliptide-ci mirror ONLY (it is a docs path, not the
   game root, so it does not change the uploaded build). Content: no accounts, no ads in
   the web build; Android build will use AdMob (state the SDK, the data it collects, the
   opt-out); Supporter IAP via Google Play Billing; contact tapiwamakandigoner@gmail.com;
   developer Tapiwa Makandigona, Kwekwe, Zimbabwe. Same tone as
   tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html. Report the URL.
3. **Play listing prep** (files only, no console work): finish `docs/play-store/listing.md`
   to the Play field limits (title ≤30, short ≤80, full ≤4000), 8 phone screenshots at
   1080×1920 captured from the live build via the headless runner (real gameplay frames,
   HUD visible, no mock-ups), feature graphic already exists. Content-rating questionnaire
   answers drafted in `docs/play-store/content-rating.md` (no violence beyond abstract
   spikes, no user interaction, no ads in v0.x web, AdMob planned for Android).
4. Then: idle on `main`, watch for the lead's "CG approved" note in this file before
   merging the trim PR and cutting the next package.
## Owner directive 2026-09-02h — Playthrough findings, fix BEFORE the package rebuild (2026-09-02 07:50Z)
Lead played the live Pages build at 390×844 (phone portrait, mouse taps at screen centre).
First frame 1.7 s, only first-party host, 0 page errors — good. Two defects, one order change.
1. **Death overlay eats retry taps (pillar violation).** After dying, the overlay says
   "tap to retry" but the RETRY / SHARE / CARD row sits exactly at screen centre, where the
   thumb already is. My next tap hit SHARE ("Copied — paste it anywhere") and every
   following centre tap did the same — the run never restarted. A tap-spamming player is
   stuck on the death screen, so the <300 ms restart pillar fails in practice even though
   the timer passes. Fix: (a) any tap OUTSIDE the button row restarts immediately;
   (b) move the button row to the bottom fifth of the screen (below the corridor, out of
   the flip-tap zone) — the corridor band is only ~30% of a portrait screen, the space is
   there; (c) ignore taps for the first ~150 ms after death so the flip tap that killed
   you does not become a button press. Add a widget test: tap at the corridor centre on the
   death overlay → new attempt started, attempt counter +1.
2. **HUD says 4%, overlay says 5%** for the same death. One rounding rule for both
   (round-half-up of the same float, or floor for both). Test pins it.
3. **Order:** fix 1 and 2 → CI green → THEN do directive 02g item 1 (rebuild
   `docs/crazygames/fliptide-web.zip`, README numbers, sha256 in progress.md). The
   CrazyGames upload waits for that zip; don't rebuild twice.
Optional, no code unless trivial: the dead space above/below the corridor on portrait
phones is a phase-3 dressing question (course preview strip, ghost stats). Note it in the
known problems, do not build it now.
## Owner directive 2026-09-02g — CrazyGames account is live; rebuild the package (2026-09-02 07:40Z)
Good gate work. Status from the owner side, then two small tasks.
**Owner-side done:** CrazyGames developer account exists and is verified; the
submission will be made from `docs/crazygames/` as soon as the zip below lands.
Android developer verification for `com.tsorostudios.fliptide` is registered
(key status "In review"). Emberdelve v0.179.0 is live on Play — no impact on you.
1. **Rebuild `docs/crazygames/fliptide-web.zip` from current HEAD.** The zip in
   the repo is from `d78dbc8` (06:03Z) and predates the KP-4 Roboto-stub fix, so
   its README still says fonts.gstatic.com is requested. Rebuild with
   `scripts/build_crazygames.sh`, re-run the blocked-hosts check on the unzipped
   build under a nested path, and update the README table + "Checks done" line
   with the new numbers and commit sha. One commit. Say "package rebuilt" in
   `progress.md` with the zip sha256.
2. **F3 and F7 are being closed owner-side.** The lead is doing the desktop
   human playthrough today; the owner will run the CI APK on a phone for the
   restart timing. Do not wait on them and do not self-approve. While at the
   gate, permitted non-gate work only: bug fixes found by the playthrough
   (they will arrive as directives), doc accuracy, test hardening. No new
   mechanics, no phase-2 code, no ads/IAP code.
3. **Playtest link** goes out owner-side after the package rebuild; expect
   feedback items in `DEMAND.md` over the next days, newest first.
## Owner directive 2026-09-02f — Lead decisions: name, money order, harness files (2026-09-02 05:55Z)

The owner has made me lead on this project ("fix everything wrong with flip,
you are the lead"). These are decisions, not suggestions; DEMAND §3/§5/§6 are
amended below and `PROJECT.md` + `features.json` are now the resume point and
the phase-1 definition of done (subagent-toolkit v3.0.1 templates). Read them
at every cold start; flip `passes` only with evidence. Acknowledge in
`progress.md`.

1. **The name is Fliptide.** Checked today: no exact match on Google Play or
   itch.io, two unrelated GitHub repos, fliptide.me/.games/.app unregistered.
   Rename NOW, before anything is registered anywhere: applicationId
   `com.tsorostudios.fliptide` (the old id was never registered with Play or
   developer verification, so nothing breaks), pubspec name/description,
   `web/index.html` title + manifest, share text, README, Pages title. The
   GitHub repos are being renamed owner-side to `fliptide` / `fliptide-ci`
   (GitHub redirects the old URLs) — update `scripts/sync_public_ci.sh`
   MIRROR_URL and the Pages base href to `/fliptide-ci/`. Feature F8.

2. **Money order changes — Play first.** The owner's Play merchant account is
   working and is the easiest way to collect money from Zimbabwe (owner,
   2026-09-02). Therefore: the Supporter IAP (Play Billing) is built before
   any ad code; ads are designed-in but not wired until the owner side has
   verified an AdMob payout path. Amend §3 accordingly. Web portals are
   acquisition and measurement, not revenue, until told otherwise.

3. **CrazyGames Basic Launch moves into phase 1** as the measurement
   instrument for the gate (it is free, non-exclusive, needs no SDK, and
   reports playtime). You prepare the package (feature F10); the owner side
   submits. The "Poki playtest recordings + 500-player fit test" wording in
   §6 is replaced by: CrazyGames Basic Launch numbers + the owner-side
   Discord playtest.

4. **Daily reproducibility is a phase-1 requirement, not a launch note.**
   Your own finding (adding chunks changed today's daily) becomes F5: course
   code = seed + generator version; an issued code never changes course.

5. **Known problems in `progress.md` become features or get closed**, not
   carried: portrait dead space (→ F6), Android share = temp file only (→ F4),
   samey chunk designs (your call, log it).

6. **Privacy policy** for Fliptide is published from the public mirror's
   Pages (`/privacy.html`) once ads or IAP code lands — it must name AdMob
   and Play Billing plainly. Not before; nothing to do in phase 1.

Order of work: F8 (rename, small) → F5 → F4 → F2/F3 numbers → F6 → F7 →
F9 → F10. Stop at the gate.

## Owner directive 2026-09-02e — Phase-1 additions from the owner side (2026-09-02 05:35Z)

The owner has asked me to guide this build. Phase gates stay the owner's call;
these are additions to phase 1, cheapest first. Acknowledge in `progress.md`.

1. **Web bundle number on the NEXT web build.** Gz size of the full deploy and
   time to first playable frame throttled to 10 Mbps, written in
   `progress.md`. DEMAND §4 bar is ≤ 6 MB gz / ≤ 5 s. If it misses, do NOT
   optimise for a week — write the number and the two honest options
   (CrazyGames-only web + Play as main surface, or renderer rewrite) and stop
   there. The owner decides the engine question with the number in hand.

2. **Share card as TEXT first, PNG second.** The owner's network shares in
   WhatsApp, where a text block pastes cleaner than an image and puts the game
   name in the preview. Wordle pattern: emoji/ASCII course map, ✗ at the death
   percentage, attempt count, link — one `share_text()` that is the same on
   web (clipboard) and Android (share sheet). Keep the PNG as the second
   button. Test that the text is ≤ 300 chars and contains the game name.

3. **Course codes.** Add a 6-character course code (base32, from the seed) so a
   friend can play the exact course you died on. Entry field on the title
   screen; the Daily is just today's code. No server. Determinism test: same
   code → same course on web and Android.

4. **Ad cadence rule, written now, enforced in code when ads arrive (phase 2):**
   never inside an attempt; never within the first 3 minutes of a fresh
   install; never within 90 s of the previous interstitial; death count is NOT
   a trigger. Rewarded ads only for skins/ghost hints. Put this in DEMAND §3
   as the standing rule and pin it with a test when the ad layer lands.

5. **Working title stays a working title.** Do not put "FLIP" into a Play
   listing, CrazyGames submission, domain or store asset. The owner is
   choosing the name; Pages URL and repo names are fine for now.

6. **Android developer verification** (Google deadline 30 Sep 2026): the owner
   side registers `com.tsorostudios.flip` + the upload key in the Console.
   Nothing for you to do except keep the key unchanged.

Playtest pool for the phase-1 gate is being organised owner-side (a Discord
of teens who already play games, plus the owner's network); when the Pages
build plays end to end, say so in `progress.md` in those words and the link
goes out.

## Owner directive 2026-09-02d — Welcome; two corrections and the fleet rules.

You are the third builder in the studio (Emberdelve on
`emberdelve@legacy/dice-builder`, Pyregrove on `pyregrove@main`). Those repos
are not yours; do not touch them. The owner side reads this file and
`progress.md` on every pass and will answer here.

Two factual corrections to §2 so the reasoning stands on the right numbers:
- Emberdelve's baseline is **38 devices with the app installed, 2 ratings,
  ONE paid unlock, USD 4.25 lifetime** (Play Console, 2026-09-01), not "2 US
  buyers". One buyer.
- Emberdelve v0.179.0 (205) was submitted to Play production at 05:20 UTC
  today; the 0.59.0 numbers are the cold-launch baseline you should compare
  against, not the ceiling.

Fleet rules that apply to you as they do to the others:
- Your DEMAND §5 release definition is exactly right. A release exists when
  the tag exists, assets are on the release page with sha256, the APK cert
  matches the pinned key, and one asset re-downloads UNAUTHENTICATED and
  hash-matches. "Built via CI" is a build.
- Phase gates are the owner's decision. When you reach a gate, write the
  numbers in `progress.md` and stop at the gate; do not self-approve.
- Publish-facing text (Pages, store copy, README on `flip-ci`) is in the
  owner's name and voice. No builder attribution on public surfaces.
- Never regenerate the upload key. Never two runners on a repo.

Carry on with phase 1.

## 1. What this is

A one-tap **gravity-flip precision runner** for Android (Google Play) and the
web (school Chromebooks, CrazyGames, Poki). You run through a tight corridor;
tap = fall to the ceiling / back to the floor. Die → restart in <300 ms with the
ghost of your best run beside you and a marker where you last died. Everyone
gets the same **Daily Course**; the share card is the course map with an X at
your death % and your attempt count.

Design constraint that outranks everything else: **the game must produce its own
content.** Every death is a shareable moment; every Daily is a comparison. If a
feature doesn't make a better clip, a better share card, or a better reason to
come back tomorrow, it is not in scope.

## 2. Why it exists (the distribution answer — the "differ test")

Emberdelve's cold Play launch (v0.59.0 baseline, Play Console 2026-09-01):
38 devices with the app installed, 2 ratings, ONE paid unlock, USD 4.25
lifetime (corrected per owner directive 2026-09-02d). "Good game + Play
listing" is the known-failing baseline to beat, not a ceiling. FLIP differs in three
inputs, each backed by receipts in
`docs/research/new-game-research-2026-09-02.md`:

1. **Content-template loop** — fails/near-wins are the TikTok/Shorts content
   (Block Blast, Geometry Dash "died at 98%"). The game exports the clip and the
   card; the owner posts.
2. **Same-seed Daily Course** — Wordle-style async comparison; kids compare at
   school. Untested twist in this genre; the phase-1 gate tests it.
3. **Web-first where US kids already are** — school Chromebooks (unblocked-games
   sites, landscape + keyboard), CrazyGames, Poki 500-player fit test — then
   Play. Same build, three surfaces.

Plus a **swappable skin layer** (original absurd creatures, our IP) so a trend
skin can ship within 48 h if the owner calls it. Never named third-party memes
or characters.

## 3. Audience, rating, money

- **Audience:** US teens 13–17 first, Gen Alpha second. Declared target age
  13+ on Play (not a Families app); art reads "cool", not "toddler".
- **Money:** free. Interstitial after N deaths (N tuned, never mid-attempt);
  rewarded ad for skin rolls/ghost hints — **never for continues**. One
  `$1.99` **Supporter** IAP: no ads + all skins. No energy timers, no
  loot boxes, no dark patterns. Ads via AdMob only (Families-certified in case
  Play reclassifies us).
- **Ad cadence rule (owner directive 2026-09-02e, standing):** never inside an
  attempt; never within the first 3 minutes of a fresh install; never within
  90 s of the previous interstitial; death count is NOT a trigger. Rewarded ads
  only for skins / ghost hints. Pinned with a test when the ad layer lands.
- **Sharing:** text share first (Wordle-style course map, ✗ at death %, attempt
  count, course code, link; ≤ 300 chars, contains the game name; same text on
  web = clipboard and Android = share sheet), PNG card second.
- **Course codes:** 6-char Crockford base32 from the seed; the Daily is just
  today's code; entry on the title screen; no server.
- **Name:** "FLIP" is a working title only — never in a Play listing,
  CrazyGames submission, domain or store asset. Owner is choosing the name.
- **Privacy:** no analytics SDK beyond what AdMob requires; privacy policy page
  published from the public repo before any store submission.

## 4. Platform + engine

- **Engine:** Flutter 3.44.9 + Flame (pinned). Chosen because the whole
  pipeline (tests, signed APK CI, original art + synth audio tooling) already
  exists from Pyregrove/Emberdelve. Web build weight is the known cost: **web
  bundle ≤ 6 MB gz, first playable frame ≤ 5 s on a 10 Mbps line** — measure
  it every release. If Poki rejects on weight, that is logged, not argued.
- **Portrait** on phone, **landscape 16:9** on web. Touch, mouse click,
  spacebar/up-arrow all flip. Poki scaling targets 640×360 / 836×470 /
  1031×580 must not crop the corridor.
- **Deterministic simulation.** Fixed-step physics, seeded RNG, replays are
  input logs. A test replays a recorded run and asserts the same death frame.
- **Cold start ≤ 2 s on Android, restart ≤ 300 ms.** Measured, in the log.
- **Offline-first.** Daily seed derives from the UTC date; no server.

## 5. Repos + release discipline

- **Private source of truth:** `tapiwamakandigona/flip`. Upload keystore and
  `android/key.properties` are COMMITTED here (owner directive 2026-08-31
  pattern: any collaborator with access can build signed). Never regenerate
  the key.
- **Public mirror:** `tapiwamakandigona/flip-ci` — snapshot-only (orphan
  commits), signing material stripped and restored from Actions secrets
  `UPLOAD_KEYSTORE_B64` / `KEY_PROPERTIES_B64`. Runs CI (analyze, test, signed
  APK+AAB, web build), hosts the **web playtest build on GitHub Pages**, and
  carries **GitHub Releases**. Sync via `scripts/sync_public_ci.sh [tag]`.
- **A release exists only when**: the tag exists, APK+AAB+web zip are on the
  release page with sha256 in the body, the APK cert matches the pinned
  upload-key SHA-256, and one asset was re-downloaded UNAUTHENTICATED and
  hash-matched. "Built via CI" is not a release. Log it.
- Versioning `0.x.y` pre-launch; `1.0.0` = first Play production submission.

## 6. Phases and gates (order not negotiable)

1. **Pillars / blockout** — flip physics, corridor renderer, chunk library,
   seeded Daily generator, death %, sub-300 ms restart, share card PNG, web
   build live on Pages. Poki playtest recordings + 500-player fit test.
   **Gate:** ≥ 3 min average playtime, ≥ 25 % of players past 3 min (Poki's
   published bar). Fail = stop, write it down, owner decides.
2. **Playable** — 15 hand-tuned campaign levels with a real difficulty curve,
   ghost, Daily + streak, practice-mode checkpoints, ads + Supporter IAP
   wired, signed APK on the public repo.
3. **Dressing** — skins (≥ 6 original creatures), death-clip export, original
   synth soundtrack with flips snapped to beat, store listing + screenshots,
   Shorts clip-cutting script for the owner.
4. **Polish / launch** — CrazyGames Basic Launch → Play internal → production;
   Poki review; level editor + share codes after launch data.

## 7. Quality bar (what a stranger must not say in 3 seconds)

- "Is it frozen?" — 60 fps on a 2019 mid-range Android and a Chromebook.
- "Where am I?" — floor/ceiling/player readable in a 9:16 thumbnail frame.
- "That was unfair." — every death is legible on the replay; no hitbox lies;
  input latency ≤ 1 frame.
- "Why would I share this?" — the share card is readable at 300 px wide and
  says the game's name.
- "Asset-flip." — 100 % original art, audio, fonts (or OFL fonts credited).
  No traced sprites, no sampled audio, no named memes.

## 8. Standing rules

- Measure, don't feel: test counts, bundle size, frame times, restart time in
  `progress.md` every session.
- Screenshots after every meaningful change: phone portrait + desktop
  landscape; close-up + wide. Read them.
- Never wait for a human. Never two runners on this repo (dirty tree you
  didn't make = back off).
- User-reported defects are logged as *user-reported*, not self-found.
- Commit + log before any boundary. Leave `main` buildable.
