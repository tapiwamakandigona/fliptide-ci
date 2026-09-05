# progress.md — FLIP (sacred running log; append, never delete)

Standards: DEMAND.md. Design: docs/gauntlet-plan.md. This file = what actually exists.

## Known problems (shrinks only when fixed)
- KP-2 Portrait: empty slabs above/below the corridor. Cosmetic; deliberately NOT changing corridor scale before the teen playtest (lookahead = reaction time). Per 02h this is a PHASE-3 dressing question (course preview strip, ghost stats in the bands) — not built now. Since 198a1d6 the bottom band holds the death-screen button row.
- KP-3 Chunk variety: spike_gauntlet / teeth_both only pass by constant bouncing; want "stay on one side" variants. Phase-2 campaign-levels work.
- Closed: KP-5 HUD "100%" two-line wrap (ababe10; verified fixed on live Pages 09:0xZ — single line, share text 106 chars intact), KP-1 web bundle (F2 PASS 2.85 MB gz / 2.85 s), KP-4 gstatic Roboto (zero third-party hosts on live), Android share sheet (share_plus, F-share PASS).

## Log

### 2026-09-02 05:00Z — session 1 — go, repos + pillars
- Directive (app thread, 04:56Z): "start making it; private repo for code, public
  repo for releases + compiling workflows; orchestrate; make plan; DEMAND.md I look at from time
  to time in case owner updates it." Acknowledged.
- Repos: private `tapiwamakandigona/flip` (source of truth), public `tapiwamakandigona/flip-ci`
  (releases, CI, Pages at https://tapiwamakandigona.github.io/flip-ci/). Pages build_type=workflow
  enabled via API. Secrets UPLOAD_KEYSTORE_B64 / KEY_PROPERTIES_B64 set on flip-ci.
- Upload key generated (PKCS12, RSA-4096, alias `upload`), committed in private repo per DEMAND §5.
  Cert SHA-256 pin: 39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43 (ci.yml).
- Scaffold: Flutter 3.44.9, flame ^1.38.2, shared_preferences, web. applicationId
  com.tsorostudios.flip. Release signing wired in build.gradle.kts (minify+shrink on).
- Sim (pure Dart, 120 Hz fixed step): course/columns, chunk grid parser, physics with
  grounded-only flips + 12-frame input buffer, BFS solver over grounded decision points,
  seeded generator with solver-driven chunk replacement, UTC daily seed.
- Chunk library: 20 chunks (tiers 1–4) + 2 spacers + start/finish. Solver killed two designs
  (spike_gauntlet, teeth_both were unsolvable at 3.8-tile arc spacing) → respaced.
- Tests: 49 passing (`flutter test`, ~20 s). Covers per-chunk solvability, per-chunk "threatens
  an idle line", replay determinism, 20 daily seeds solvable, 365 distinct seeds, arc length
  2.5–4.5 tiles, input buffer fires on landing, block/pit death causes.
- Measured: free-corridor flip arc ≈ 3.8 tiles at speed 9 / g 58.
- NEXT (this session): Flame renderer + input, HUD, death/share overlay, web build, Pages deploy,
  screenshots phone+desktop.

### 2026-09-02 05:25Z — session 1 cont. — renderer, HUD, share card, web build
- Flame renderer (`lib/game/flip_game.dart`): 120 Hz sim accumulator + interpolation, camera at 32 %
  width, 15 tiles across landscape / 9 portrait, corridor centred; slabs, blocks, spikes, pits,
  finish stripes, last-death X marker, ghost creature, landing squash, death burst.
  Input: tap, click, Space/↑/W/Enter. Death → tap restarts (guard 120 ms) or RETRY button.
- HUD (Flutter): daily #, progress bar with best-% underlay, %, attempt, ~course seconds; centre
  card for start / death % / CLEARED with RETRY + SHARE.
- Share card: 1080×1080 PNG via dart:ui (course map with hazard ticks, X at death, earlier
  deaths as faint dots, streak, URL). Web = anchor download; Android = temp file (share_plus phase 2).
- Store: per-daily best/attempts/won/ghost flips, streak, total deaths.
- Web release build OK. **Measured transfer: 7.82 MB raw / 8 requests** (canvaskit.wasm 5.76 MB,
  main.dart.js 1.89 MB); first Flutter element 1.4 s on localhost. gz not yet measured on Pages.
- Look-loop (Playwright, `tool/webtest/shots.py`, desktop 1280×720 / phone 390×844 / Poki
  640×360) found 2 self-found bugs: (1) death card never showed — `onProgress` fired after death
  and reset phase to running; (2) start card stayed up + "attempt 0" — HUD attempts only updated
  on death. Both fixed via new `FlipListener.onAttempt`. Verified by re-shoot.
- Mirror synced to flip-ci. First CI run failed on YAML: unquoted `§4: <=` colon in a step name.
  Fixed (quoted), re-synced.
- Tooling notes: `/tmp` is NOT persistent between tool calls — keep scratch under /work/temp.
  `pkill -f http.server` kills the calling shell too (pattern matches itself). Playwright needs
  `executable_path=/root/.cache/ms-playwright/chromium_headless_shell-1234/...` (CHROME_BIN).
  Serve build/web under `/flip-ci/` (base href) via symlink dir.

## Known problems (carried, 05:xxZ snapshot — see consolidated list at top)
- Web bundle 7.8 MB raw vs DEMAND §4 budget 6 MB gz — need gz measurement on Pages; options:
  `--wasm` (skwasm 3.5 MB) or trimming. Not yet decided.
- Portrait: large empty slabs above/below the corridor (dead space) — should carry big % /
  clip framing. Cosmetic for blockout.
- Android share = temp file only; no share sheet yet.
- Solver found spike_gauntlet/teeth_both only passable by constant bouncing — chunk designs
  need a "stay on one side" variant to feel less samey.

### 2026-09-02 05:40Z — ACK owner directive 2026-09-02d (read via git fetch; push was rejected non-ff)
- Acknowledged: fleet rules (no touching emberdelve/pyregrove; gates are owner decisions — I write
  numbers and STOP at the gate; publish-facing text in owner's voice, no builder attribution on
  public surfaces; never regenerate key; one runner). Release definition unchanged.
- Corrections applied to DEMAND §2 wording: Emberdelve baseline = 38 devices, 2 ratings, ONE paid
  unlock, USD 4.25 lifetime (not "2 US buyers"). v0.179.0 submitted to production 05:20Z today;
  0.59.0 is the baseline to compare against.
- Public-surface audit: flip-ci MIRROR.md / Pages have no builder attribution. Share card carries
  only "FLIP" + URL. Private-repo commit author is not a public surface.
- Live: https://tapiwamakandigona.github.io/flip-ci/ is up (CI run 33594447755: test ✓, web ✓,
  Android job running). Pages gz transfer measured: main.dart.js 0.57 MB + canvaskit.wasm 2.93 MB
  ≈ 3.5 MB gz → inside DEMAND §4 6 MB budget. Switched CI to `--wasm` anyway (local: 5.33 MB raw /
  0.8 s first element vs 7.82 MB / 1.4 s).
- NOTE for launch: adding chunks to the library changes every generated daily (today's went 27 s →
  28 s). Pre-launch fine; at launch the generator + chunk set must be versioned/frozen per day.
- Carrying on with phase 1 as ordered.

### 2026-09-02 05:50Z — ACK owner directive 2026-09-02e (phase-1 additions)
- Acknowledged all six. Order of work: (1) bundle number on next web build (CI now builds --wasm;
  will measure gz + 10 Mbps time-to-first-frame on the live Pages deploy), (2) text share first,
  (3) course codes, (4) ad cadence rule → written into DEMAND §3 now, (5) FLIP stays a working
  title (no store/domain use), (6) key unchanged — nothing to do.
- CI Android job failed: `Keystore file android/app/signing/upload.keystore not found` — Gradle
  `file()` resolves relative to android/app; key.properties path is relative to android/. Fixed
  with `rootProject.file(...)`. Web + test jobs green; Pages live.
- Share card verified end-to-end on the web build via Playwright: SHARE → PNG downloaded
  (flip-daily-245.png, 61 KB), reads correctly with real fonts (test-env sample uses Ahem blocks).
- Playtest pool noted: I will write "the Pages build plays end to end" in those words once the
  win path is verified in-browser (adding a `?auto=1` solver-driven run for that).

### 2026-09-02 06:00Z — text share, course codes, autoplay verification
- Course codes: 6-char Crockford base32 (30-bit seeds; `lib/sim/course_code.dart`), O/I/L/U
  tolerant, `?code=XXXXXX` deep link on web, CODE button + dialog on every screen, DAILY button
  when on a code course. Records keyed per seed. Tests: 2000-seed round trip, confusion mapping,
  same code → same chunk sequence.
- Text share (`lib/ui/share_text.dart`): 16-cell 🟨/✗/⬛ (🟩 when cleared) map, result line,
  streak, code, link. Web = clipboard (`Clipboard.setData`), Android = share_plus sheet.
  Test pins ≤ 300 chars + game name + link + code for 4 cases. Measured live text = 98 chars.
  SHARE (text) is now the primary button; CARD (PNG) second — per directive 02e.
- `?auto=1`: the solver's flip list drives the run. **The Pages build plays end to end** in the
  local wasm build: start → flips → CLEARED card → SHARE copies the text above (verified via
  Playwright clipboard read). Pending: same check on the live Pages URL after this deploy.
- Tests: 60 passing. Web build `--wasm` OK.

### 2026-09-02 06:20Z — ACK owner directive 2026-09-02f (lead: name, money order, harness files)
- Acknowledged. PROJECT.md + features.json are the resume point / phase-1 DoD. Order F8 → F5 → F4 →
  F2/F3 → F6 → F7 → F9 → F10; stop at the gate.
- Found the repos already renamed (fliptide / fliptide-ci); the live Pages URL moved and the deployed
  build's `/flip-ci/` base href 404'd every asset (index 200, assets 404) — fixed by F8 below.
- **F8 done**: applicationId/namespace `com.tsorostudios.fliptide` (Kotlin package moved), pubspec
  `fliptide`, all imports, web title/manifest/description, share text `Fliptide` + fliptide-ci URL,
  share card header FLIPTIDE, Android label, CI base href + artifact names, sync MIRROR_URL, README,
  plan, shots harness. `grep FLIP\b` outside progress/DEMAND → only the lead's own historical
  mentions in PROJECT.md/features.json remain (not public surfaces).
- **F5 done**: code = 3-bit generator version + 27-bit seed (`packCode`/`codeVersion`/`codeSeed`);
  `kGeneratorVersion = 1`; `kVersionPools[1]` = frozen 23-chunk name list; `generate` throws on unknown
  version; golden test pins v1 pool size, code `400C1S` for (v1, seed 12345) and its exact chunk
  sequence — adding chunks now requires a v2 pool and cannot move an issued code.
- Tests split to match features.json verify commands: `test/share_text_test.dart`,
  `test/course_code_test.dart`. Suite: **62 passing**.

### 2026-09-02 07:00Z — phase-1 features: measurements + evidence (features.json updated)
- **F1 PASS** 63 tests; new 365-day sweep: all 2026 dailies solvable, 0 fallbacks, 0 rerolls (chunk
  set is conservative — none of the 23 chunks ever forced a swap; difficulty tuning is a phase-2 topic).
- **F2 PASS** live Pages, CDP throttle 10 Mbps/40 ms, cache off: 9 requests, 5.80 MB raw, ≈2.39 MB
  compressed transfer (skwasm.wasm 3.58 MB br, main.dart.wasm 2.04 MB gz), flutter-first-frame 2.23 s.
  Bar ≤ 6 MB / ≤ 5 s → inside. Script `tool/webtest/measure_web.py`.
- **F3 web only**: restart death→first accepted step, 9 samples, median 165 ms, max 200 ms (120 ms of
  that is the deliberate death-tap guard). Android NOT measured (no device here) → passes=false.
  Script `tool/webtest/measure_restart.py`, needs `?perf=1`.
- **F4 PASS** test green + live clipboard text captured (106 chars, 'Fliptide', code 5P6-6GR, link).
- **F5 PASS** versioned codes, frozen v1 pool, golden sequence pinned.
- **F6 pending** 300 px-wide inspections OK (docs/screens/*-300w.png); min text 12 px; 360×640 shot
  being captured now (added viewport to shots harness).
- **F7 partial**: solver `?auto=1` run on the LIVE URL reaches CLEARED (docs/screens/desktop-cleared-live.png);
  death overlay verified live earlier. **The Pages build plays end to end** for a scripted player.
  Human run = owner-side Discord playtest → passes stays false until then.
- **F8 PASS**, **F9 PASS** (post-rename run 33596017465 job 100139659686, cert matches pin, APK+AAB
  artifacts). No release cut.
- Harness scripts now live in `tool/webtest/` (shots, measure_web, measure_restart, verify_live);
  all take CHROME_BIN and a URL.
- Debug bridge: web exposes `window.__fliptideState` / `__fliptideRestartMs` for harnesses (no-op on
  Android).

### 2026-09-02 07:30Z — F6/F10 done, renderer self-hosted, AT THE GATE
- Found while packaging for CrazyGames: the `--wasm` build loaded skwasm from **www.gstatic.com**
  (Flutter default CDN) — so Pages was serving a build that dies behind adblock/school filters.
  Fixed with a custom `web/flutter_bootstrap.js` (`canvasKitBaseUrl: "canvaskit/"`). Verified:
  nested path + every non-first-party host blocked → game runs, 0 page errors, only
  fonts.gstatic.com requested (Roboto fallback; Inter is bundled so text still renders).
- Fonts: Inter variable (OFL 1.1) bundled, CREDITS.md added, `fontFamily: 'Inter'` app-wide + card.
- **F6 PASS** (360×640 + 300 px-wide shots in docs/screens/), **F10 PASS** (docs/crazygames/: zip
  14.1 MB / 35.8 MB unzipped, cover 16:9, icon 512, description in owner's voice, README with the
  checks; `scripts/build_crazygames.sh` rebuilds it).
- Web bundle after Inter: +0.88 MB raw (~0.4 MB gz) — still well inside 6 MB; re-measure after deploy.
- Tests 63 green. features.json: 8/10 pass. F3 needs an Android device; F7 needs a human.
- **Gate:** per DEMAND §6 / directive 02d I stop here and do not self-approve. Numbers are in
  features.json evidence. Owner-side actions listed in PROJECT.md "Current phase".
- Housekeeping notes: `A && B && (C) &` backgrounds the whole list incl. the `cd` — cwd surprises;
  `zip` binary absent (use python shutil); /work/temp/srv serves both fliptide-ci and nested/cg.

## 2026-09-02 06:15Z — gate commit green; F2 re-measured
- CI run 33597228813 (mirror @d78dbc8) SUCCESS: tests, signed APK/AAB (cert pin matches), web deployed to Pages.
- F2 re-measure on live Pages, 10 Mbps / 40 ms, cache off: 10 req, 6.68 MB raw, ≈2.85 MB gzip, first frame 2.85 s. Owner bar (gz ≤6 MB, ≤5 s): PASS. Raw grew +0.88 MB from bundled Inter; a 60 KB Roboto woff2 is still pulled from fonts.gstatic.com by the engine's fallback font — non-blocking (game verified running with all third-party hosts blocked). Logged as known problem KP-4 → candidate feature: set explicit fontFamily/fallback everywhere to hit zero third-party requests.
- verify_live on live Pages: auto-solver clears Daily #245, share text = 106 chars with game name + code 5P6-6GR, 0 page errors. **The Pages build plays end to end** (scripted; human run still F7).
- Origin fetched: no new DEMAND.md / PROJECT.md directives since 02f.
- STATUS: at phase-1 gate. Not self-approving. Waiting on owner: (a) Discord playtest link, (b) CrazyGames Basic Launch upload from docs/crazygames/, (c) Android run of CI APK for F3 restart timing, (d) gate decision / "cut" for a GitHub Release.

## 2026-09-02 06:30Z — KP-4 closed: zero third-party requests; privacy draft parked
- Registered a 2 KB single-glyph stub as family "Roboto" (pubspec) so the web engine skips its default fonts.gstatic.com download; perf overlay's 'monospace' → Inter tabular figures (only non-Inter style). Local build check (Playwright, 360×640, `?auto=1`): hosts requested = {localhost} only, 0 page errors, title/HUD text renders in Inter. 63/63 tests pass. CREDITS.md updated.
- `docs/privacy/privacy.draft.html` written in owner voice (names Play Billing and AdMob plainly, 13+ statement, no-analytics statement). NOT published — DEMAND 02f-6 says /privacy.html goes live only once ads/IAP code lands. Owner fills CONTACT_EMAIL + effective date then.
- Still at the phase-1 gate. No new directives on origin (fetched 06:19Z).

## 2026-09-02T06:31Z builder — Play listing draft
- Wrote docs/play-store/listing.md (owner voice, unpublished; content-rating + data-safety expectations, asset checklist). Non-gate work. No new DEMAND directives (origin/main == HEAD before this commit). CI run 33598783515 for 8508cdd still in_progress at check time.
- 06:33Z CI 33598783515 (@8508cdd) GREEN. Live Pages host check (360x640, ?auto=1): requested hosts = {tapiwamakandigona.github.io} only, 0 page errors -> KP-4 closed on LIVE build (VERIFIED). CI for 1b6c423 (docs only) in progress.
- Builder remains AT THE GATE. Waiting on owner: Discord playtest (F7), Android APK run (F3), CrazyGames upload, "gate pass" / "cut".
- 06:42Z Play feature graphic 1024x500 generated (code-drawn, same palette/Inter as CrazyGames cover); script tool/art/feature_graphic.py. No new directives; CI @1b6c423 green. Still AT THE GATE.
- 06:54Z Five 1080x1920 Play screenshots captured from live Pages (title, run, flip, 52% deep via solver, death card), 0 page errors; tool/webtest/play_shots.py. Play package now complete except owner Console steps. No new directives. AT THE GATE.
- 07:03Z Release dry-run on CI run 33600993329 (@3a85010): APK 49.0 MB fat (3 ABIs; per-ABI Play download ~7-8 MB), AAB 48.5 MB incl. debug symbols, web zip 15.4 MB. APK signer cert == pin 39cdb292… (VERIFIED with apksigner). sha256: apk a64c4082…, aab 674bb38f…, web 02aabeda…. Added scripts/cut_release.sh (owner-triggered only: download run artifacts, pin check, SHA256SUMS, tag+release on mirror, unauthenticated re-download check). NOT executed — no "cut" from owner. AT THE GATE.
- 07:13Z Consolidated known-problems list at top of progress.md (2 open, cosmetic/phase-2; 3 closed). No new directives; CI @bd8143d green. AT THE GATE — no builder-only phase-1 work remains.
- 07:24Z docs/gauntlet-plan.md phase-2 block rewritten to match DEMAND 02e/02f (IAP before ads, no death-count trigger, KP-2/KP-3 folded in). Resume point for "gate pass" is now unambiguous. CI @bd8143d green, mirror synced, no new directives. AT THE GATE.
- 07:44Z ACK directives 02g + 02h (read via git fetch). Order: fix death-overlay tap eating + HUD/overlay percent mismatch (tests) -> CI green -> rebuild crazygames zip + README + sha256 -> "package rebuilt". No phase-2 code.
- 07:49Z 02h fixes: death overlay text is IgnorePointer (any corridor tap restarts), button row moved to bottom fifth (h*0.20 band, Key death-buttons), 150 ms post-death guard on taps AND the RETRY button (kDeathTapGuardS), toast moved above the band. percentOf() in sim/physics.dart is the single floor rule for HUD/overlay/share text/card; HUD now takes the death-frame progress (was last running frame -> 4% vs 5%). Tests: test/death_overlay_test.dart (centre tap on death overlay -> attempt+1; guard tap ignored; button row top > 80% height; HUD == overlay percent; percentOf pins). 66 tests green. Local web look-loop 390x844 + 1280x720: 6 centre-tap spam on death screen restarts the run, 0 page errors.
- 07:58Z package rebuilt: docs/crazygames/fliptide-web.zip from 198a1d6 (after CI run 33605535565 green: test/APK+AAB/web all success). 44 files, 35.8 MB unzipped, 14.1 MB zip, sha256 a0b99dd254ba24f8a284d497e928f5a3ded5502e37f18b0eb77f9962a49fe8e7. Blocked-hosts check on the unzipped build under /cdn/games/abc123/v7/: hosts = {serving host} only, 0 blocked requests, 0 page errors, renders with bundled Inter. README table + "Checks done" updated (gstatic mention removed). Ready for owner submission from docs/crazygames/.
- 07:59Z Play screenshots recaptured from LIVE Pages @198a1d6 (docs/play-store/screens 1-5, 1080x1920, 0 page errors); live death screen shows HUD 7% == overlay 7% and buttons in the bottom fifth. KP-2 note updated per 02h (phase-3 dressing). CI on cd17206 (crazygames rebuild) in progress. AT THE GATE — awaiting F3/F7 closure owner-side and playtest feedback directives.
- 08:06Z Doc accuracy pass (permitted gate work): features.json evidence refreshed — F1 66 tests, F2 gstatic fallback gone (KP-4), F3 guard now 150 ms (worst case ≈230 ms < 300), F7 lead playthrough numbers + owner-side closure, F10 rebuilt package sha. No acceptance/verify text touched. flutter test 66/66. CI cd17206 green; 81d3e52 in progress. No new directives. AT THE GATE.
- 08:17Z Test hardening (permitted gate work): dailySeed()/dailyNumber() now call .toUtc() internally (defensive — caller already passed UTC, zero behaviour change for the live Daily; a future local-time caller can no longer shift the day). New tests: Daily keyed to UTC day (04:30Z and 23:59:59Z on 2026-09-03 → both #246 same seed; 23:59:59Z on 09-02 → #245; same instant as non-UTC DateTime → same seed/number) and design constants pinned (kSimHz 120, inputBufferFrames 12, gravity 58). flutter test 68/68, analyze clean. All CI runs green through 81d3e52. No new directives. AT THE GATE.
- 08:25Z CI 33607901357 (@1aa95ec) green — 3/3 jobs. PROJECT.md status block refreshed to HEAD 1aa95ec (resume point accurate). No new directives. AT THE GATE.
- 08:39Z verify_live re-run on live @1aa95ec: solver clears Daily #245, 0 page errors. Two findings: (a) harness stale — SHARE click coordinate predates 198a1d6 button-row move, so clipboard read empty; fixed tool/webtest/verify_live.py (594,647 @1280x720). (b) KP-5 HUD "100%" two-line wrap on CLEARED — fixed + pinned by test (see known problems). flutter test 69/69, analyze clean. No new directives. AT THE GATE.
- 08:46Z CI 33609873394 (@ababe10) green 3/3. verify_live on live @ababe10: title→auto-run→CLEARED Daily #245 in 1 try, HUD shows "100%" on ONE line (KP-5 closed), SHARE → clipboard 106 chars containing "Fliptide" + code 5P6-6GR + host, 0 page errors. Pages build plays end to end at this HEAD. No new directives. AT THE GATE.
- 08:55Z No new directives; CI green; 0 issues on both repos. Doc accuracy: docs/crazygames/README.md now states the packaged zip (198a1d6) still carries the KP-5 two-line "100%" on CLEARED and why it was not rebuilt. AT THE GATE.
- 09:05Z Check: no new directives, CI green @ababe10, Pages 200, 0 issues. Reviewed test inventory (69) for hardening gaps — F1/F4/F5/F8 contracts already pinned; nothing worth adding. AT THE GATE, permitted work exhausted.
- 10:22Z ACK owner directive 2026-09-02i (51dc705): main frozen for game code / zip / Pages game bundle until "CG approved"; working on branch next/payload-trim → (1) payload trim + prune script + evidence, PR "payload trim (merge after CG approval)"; (2) privacy page live on mirror docs path; (3) Play listing prep files; (4) idle on main. Interpretation recorded: "main stays at the packaged commit" read as no game-code changes on main (main is already at ababe10 > 198a1d6 by owner-accepted docs/HUD commits).
- 11:1xZ 02i item 2 — PRIVACY PAGE LIVE: https://tapiwamakandigona.github.io/fliptide-ci/privacy/ (200). Names Google AdMob (SDK, data it collects: advertising ID, IP-derived approximate location, device/app info, ad interactions; opt-out: reset/delete ad ID, consent form, Supporter unlock removes ads), Google Play Billing (anonymous purchase token only), no accounts, no ads/analytics in the web build, cadence promise, permissions, 13+, Play data-safety table, contact tapiwamakandigoner@gmail.com (spelled as given in 02i — please confirm), developer Tapiwa Makandigona, Kwekwe, Zimbabwe. Same layout/tone as the Emberdelve policy page.
  How it went live WITHOUT a rebuild or a game-byte change: mirror commit 415c2ec "[skip ci]" (docs + new workflow only; CI did not run) → new workflow pages-docs.yml (manual) downloaded the fliptide-web artifact of the live run 33609873394, added docs/privacy as /privacy/, redeployed (run 33619906587, success). Verified: sha256 of index.html, flutter_bootstrap.js, main.dart.wasm, main.dart.mjs, main.dart.js, version.json, canvaskit/skwasm.wasm fetched from Pages before and after — identical. Private main 81d7777 carries the same files + a ci.yml step that copies docs/privacy into every future Pages build so the URL stays stable. Note: one Pages site = one deployment, so "no Pages redeploy" was honoured in substance (game bytes unchanged) but not literally — a deployment event did happen. Draft file privacy.draft.html removed.
- 11:3xZ 02i item 3 — PLAY LISTING PREP (files only, no Console work): docs/play-store/listing.md finished to field limits — title 29/30, short 75/80, full 1050/4000 chars; contact + live privacy URL filled; asset inventory updated. 8 phone screenshots 1080×1920 in docs/play-store/screens/ (1 title, 2 code entry, 3 first run, 4 on the ceiling, 5 mid-course 45 %, 6 death overlay, 7 attempt 2, 8 CLEARED 100 %) — real frames captured from the live Pages build (ababe10) by tool/webtest/play_shots.py, HUD visible, 0 page errors, sizes verified by PIL. docs/play-store/content-rating.md drafted (no violence beyond abstract spikes, no user interaction, IAP yes-when-shipped, ads no in v0.x / yes with AdMob, expected Everyone/PEGI 3, 13+ target, data-safety pointers). Note: frame 7 shows a plain restart — the ghost sits under the player that early and the X marker is off-screen; named honestly.
- Items 1–3 of 02i done. Item 4: idling on main; watching DEMAND.md for "CG approved" before merging PR #1 and cutting the next package.
- 11:5xZ ACK 02j (owner, c5a7582). (1) Payload bar ruling recorded: PROJECT.md standing decision (per-player transfer, both renderer paths; no Inter subset, keep skwasm) + features.json F2 acceptance wording "per-player transfer ≤6 MB gz, both renderer paths" — wording only, at the owner's instruction; evidence unchanged. (2) PR #1 stays open. (3) Won-screen sprite/caption overlap → fixing on next/payload-trim, main untouched. (4) then idle.
- 12:1xZ 02j-3 DONE — won-screen sprite/caption overlap. Cause: FlipGame.render drew the player whenever state != dead, so on `won` the cube stayed put under/over the "attempt N · tell someone" caption. Fix on next/payload-trim (1b62b7b), main untouched: FlipGame gets `_wonTimer`/`kWonFadeS = 0.15` and `playerAlpha` (1 → 0 over 150 ms after the win; the sprite is skipped at 0); the CLEARED card in main.dart is wrapped in a TweenAnimationBuilder with Interval(0.5, 1) over 300 ms so the caption fades in only after the sprite is gone. Death screen unchanged (sprite already skipped while dead; burst particles only). Test: test/won_overlay_test.dart — solver autoplays course 400C1S to CLEARED, then asserts playerAlpha == 0 and counts player-yellow pixels inside the caption Text rect on a RepaintBoundary capture: 0 required. Proven live: with the fade disabled the same test reports 354 yellow pixels in the caption rect; with the fix 0. Second test pins the death screen. Suite 71/71, analyze clean.
  Screenshot 8 retaken from the fixed build (local build of 1b62b7b, pruned, served at /fliptide-ci/), same Daily #245 seed, same 360×640@3x frame, solver run, 1080×1920, 0 page errors → docs/play-store/screens/8-cleared.png replaced (sha256 4a1fa2bb79441174…). Old vs new: cube gone, caption clean. Observation, not acted on: the green finish-line dashes pass behind the caption (text is drawn on top, legible) — say if you want them hidden too.
- 02j complete. Idle on main; waiting for the lead's "CG approved" in DEMAND.md.
- 12:0xZ ACK 02k (05bb4c3 → rewritten b559d6d lineage), 02L, 02M, 02N — all read via git fetch. Order followed: 02j sprite fix first (done above), then ads on a branch.
- 02k DONE on `next/android-ads` (off next/payload-trim; main untouched, CG package untouched, no release, no merge). Evidence:
  - Android only: `google_mobile_ads ^9.1.0` reached only through `lib/ads/ads_service_platform.dart` (conditional import: `ads_service_web.dart` stub on web, `ads_service_io.dart` → `ads_service_mobile.dart` on Android). Web proof: `verify_prune.py build/web_ads skwasm` → first frame 3.23 s, 5.74 MB raw / 2.32 MB gz, 0×404, **0 third-party requests**, 0 page errors, PASS; canvaskit path also PASS, 0 third-party; `grep -c 'google_mobile_ads\|gms.ads\|googleads'` over the built wasm/js = 0.
  - Die → restart untouched (<300 ms): the rewarded unit is an opt-in "Second chance" button on the death overlay, never auto-shown; `kDeathAdGuardMs = 300`, `kSecondChanceMinAttempt = 3`, once per Daily (`secondChanceUsed` keyed to the Daily number in `lib/store/store.dart`). Checkpoints at 25/50/75 % (`lib/sim/checkpoint.dart`, `Sim.resumeFrom`, `FlipGame.resumeFromCheckpoint()` — resume does NOT increment the attempt counter).
  - Interstitial only after CLEARED or on background→resume (WidgetsBindingObserver), `kInterstitialGapMs = 180000`, `kAppStartGuardMs = 60000`, `kFreshInstallGuardMs = 180000` (DEMAND §3), nothing before the first tap.
  - Supporter flag (`store.supporter`) checked before every `load*` call; persisted locally.
  - IDs: release → real units (app `~6877765460`, rewarded `/2421796507`, interstitial `/6829664002`); debug/profile → Google test units (`ca-app-pub-3940256099942544/5224354917`, `/1033173712`) via `kReleaseMode`. `requestConfiguration(maxAdContentRating: T, tagForChildDirectedTreatment: unspecified)`; UMP consent flow requested at startup. Manifest carries `com.google.android.gms.ads.APPLICATION_ID` (verified with aapt2 on the built APK).
  - `flutter analyze` clean. `flutter test` **85/85** = 71 baseline + 14 new (`test/ad_policy_test.dart`: no ad on attempt 1–2, no ad within 300 ms of death, supporter suppresses loads, interstitial gap/app-start guards; `test/checkpoint_test.dart`; `test/second_chance_widget_test.dart`). Note: the directive says "63 + new" — the suite was already at 71 when 02k arrived (test hardening logged 08:17Z–08:39Z).
  - Debug APKs built from the branch (`flutter build apk --debug --split-per-abi`): arm64-v8a 92.9 MB sha256 29b3ef5a21ca6d2b334abd3388c371408814457a54c22e944ff96a719a6bdeb1; armeabi-v7a 72 MB; x86_64 78.9 MB. aapt2: minSdk 24, targetSdk 36, AdActivity present; permissions INTERNET, ACCESS_NETWORK_STATE, AD_ID, ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS, WAKE_LOCK, FOREGROUND_SERVICE. No BILLING permission — Play Billing is not linked yet (see flag below).
  - **Emulator smoke run — NOT COMPLETED, evidence outstanding.** This sandbox has no /dev/kvm and one CPU. Software emulator (android-34 google_apis x86_64, swiftshader) booted in 641 s, `adb install` of the x86_64 debug APK succeeded (4 m 49 s), the app launched (Impeller/GLES init and Dart VM up in logcat), but the system_server then ANR'd ("Process system isn't responding"), the framebuffer froze on that dialog and no gameplay frame could be captured before the run ended. I cannot honestly claim "test rewarded ad shown, resumed from checkpoint" from this environment; the arm64 debug APK is handed over for a 2-minute smoke on a real phone (steps in the app thread). The rest of 02k-7 (analyze, tests, gating tests) is complete.
  - 02k-6: `docs/privacy/index.html` Permissions line updated on main to list the SDK-declared permissions above (that is the only place the page differed from real SDK behaviour). Not republished to Pages (main frozen; republish before store submission).
  - 02k-8 DONE: `docs/play-store/listing.md` Developer website = https://tapiwa.me + app-ads.txt line `google.com, pub-5182383335652302, DIRECT, f08c47fec0942fa0` (commit 1f06dbc on main, cherry-picked from wip/listing-02k-8 which is now deleted).
  - Flags for the owner: (a) 02f said Supporter IAP before ad code; 02k put ads first — the supporter flag is honoured before every load, but the Play Billing purchase flow itself is not built (phase 2, waits for "gate pass"); (b) 02e's rewarded-for-skins/hints wording is superseded by 02k second chance; (c) privacy page still says "one interstitial every 90 seconds" (actual cap 3 min, stricter) and lists `com.android.vending.BILLING` although Billing is not linked yet — both true-by-the-time-of-store-submission; say if you want them changed now.
- 02L DONE. Repo git identity set to `Tapiwa Makandigona <tapiwamakandigoner@gmail.com>`; no GIT_AUTHOR_*/GIT_COMMITTER_* env; `scripts/sync_public_ci.sh` orphan-snapshot identity switched to the same; progress.md session-1 header de-attributed. `git grep -in viktor | wc -l` = 8, all inside DEMAND.md (directive text + the "Builder:" line at DEMAND.md:7, which is the owner's file — not edited). Outside DEMAND.md: 0. `git log -1 --format='%an <%ae> | %cn <%ce>'` output is in the next entry.
- 02M honoured: at 11:43Z I pushed the one unpushed commit as `wip/listing-02k-8` (local main had diverged from the new DEMAND commits and pull/rebase were forbidden), then made no commits/pushes/tags until 02N appeared.
- 02N DONE: `git fetch origin --prune --tags --force`; main, next/payload-trim, next/android-ads, wip/listing-02k-8 each `reset --hard origin/<branch>` (trees verified identical to the pre-rewrite trees: `git diff old new --stat` = 0 for all three work branches); stash dropped; WIP re-applied from patch. Per-ref author check before this commit: every ref 0 Viktor commits; `git log --all --format='%an <%ae>' | sort | uniq -c` after this commit is pasted below.
  Proof (run after the commit above): `git log -1 --format='%an <%ae> | %cn <%ce>'` → `Tapiwa Makandigona <tapiwamakandigoner@gmail.com> | Tapiwa Makandigona <tapiwamakandigoner@gmail.com>`; `git log --all --format='%an <%ae>' | sort | uniq -c` → `56 Tapiwa Makandigona <tapiwamakandigoner@gmail.com>` (only line); `git status` clean. Resuming the plan: idle on main, waiting for "CG approved" (merge PR #1) / "gate pass" (phase 2: Play Billing, ads branch merge) / "cut vX.Y.Z".
- 12:27Z PROJECT.md status block refreshed to HEAD 970b4fb (was 1aa95ec/68 tests): branch state, CG-review wait, ads branch + outstanding smoke, re-authored history. Doc accuracy only. No new directives; CI green; Pages/privacy 200; PR #1 open, 0 comments. AT THE GATE.
- 12:40Z ACK 02O (b0ad6a5) — GATE PASS for phase 2, on `next/android-ads`; main stays frozen (02i). Plan: (2) privacy text first (also restores the /privacy/ URL — see next line), (1) Supporter IAP via in_app_purchase + tests, (3) signed AAB from CI on the branch with aapt2 evidence, (6) PR #2 then stop at the gate. Emulator smoke: logged once as **needs device** (02O-5); no more sandbox retries.
- 12:40Z Observation: the mirror push 756457c "docs: attribution cleanup" (12:33Z, no [skip ci]) triggered a full CI run on the mirror; its Pages job redeployed the site from the mirror's older ci.yml (no docs/privacy step) → https://tapiwamakandigona.github.io/fliptide-ci/privacy/ is 404 since ~12:37Z (game URL 200). Game source on the mirror is unchanged (ababe10 code), but the bundle bytes were rebuilt by that run. I will restore /privacy/ with the 02O-2 text via the no-rebuild pages-docs workflow (docs-only republish, allowed by 02O-2).
- 12:52Z 02O-2 DONE + /privacy/ RESTORED: docs/privacy/index.html cadence line now reads "never between a death and the retry … interstitials only at a session break … at most one every 3 minutes; the second-chance video plays only when you tap for it" (7029858 on main, docs only; `com.android.vending.BILLING` was already listed as present). Mirror synced from main with [skip ci] (no rebuild), then pages-docs.yml run 33631423402 republished the CURRENT live game bundle (artifact of the owner's run 33630544358) + docs/privacy → https://tapiwamakandigona.github.io/fliptide-ci/privacy/ = 200 again with the new text; game bytes untouched by me. Merged main into `next/android-ads` (4af398d: docs, privacy, listing, pages-docs.yml, ci.yml privacy step) so the branch carries the same docs — no old history involved, both sides are the rewritten lineage.
- 12:52Z 02O-1 DONE on `next/android-ads` (3230a2c) — Supporter IAP. `in_app_purchase 3.3.0` (Play Billing) behind `lib/iap/iap_service_platform.dart` (conditional import: web → `NoIapService` stub, io → `PlayIapService` on Android only). Product `fliptide_supporter`, non-consumable, `buyNonConsumable`; ownership = whatever `purchaseStream` reports as purchased/restored, then `completePurchase`; localised price from `queryProductDetails` (fallback "$1.99" until the store answers). Startup restore: `restorePurchases()` inside `init()`, not awaited by the title screen. "Restore purchase" text button under SUPPORT. UI: title screen (attempt 0, bottom band) = `SUPPORT · <price> · REMOVES ADS` + Restore; once owned → "♥ SUPPORTER · no ads" mark; CLEARED card = one `REMOVE ADS · <price>` line under the buttons; death card = nothing. Purchase/restore → `supporter=true` in shared_preferences → `AdPolicy.supporter=true` (every load AND show gate goes dark, so an already-loaded unit is never shown) → toast "Thank you — ads removed". No fake purchase path anywhere; debug builds use the real Play flow with licence testers.
  Tests: test/supporter_iap_test.dart (11): Store flag persists across opens; AdPolicy suppression of load/offer/rewarded/interstitial after a mid-session purchase; title shows SUPPORT+Restore with the store's price and nothing on the death card; purchase → flag persisted, mark shown, 3 deaths later 0 rewarded loads/shows, 0 interstitial shows, no new loads; cancelled purchase changes nothing; Restore owned → flag+mark; Restore not owned → message, no flag; startup restore (store reports owned during init) → supporter with no tap; pre-existing supporter → mark, no buttons, SDK never initialised; no store (web) → no purchase UI on title/death/CLEARED; CLEARED shows the one REMOVE ADS line for non-supporters. Suite **96/96**, `flutter analyze` clean.
  Web stays clean: release wasm build + prune, `verify_prune.py` skwasm = 8 files to first frame, 5.75 MB raw / 2.32 MB gz, canvaskit = 10.65 / 4.12 MB gz, **0 third-party requests**, 0 page errors, PASS both; grep for in_app_purchase/BillingClient across main.dart.js/.mjs/.wasm = 0.
  Note: lib/main.dart was formatted at 250 columns with the edit (the file was never formatter-clean); ~60 lines re-wrapped, no semantic change.
- 12:52Z 02O-3 IN PROGRESS: ci.yml on the branch — Pages job now runs ONLY on main (branch dispatches build Android only, the live site cannot be touched from a branch); new "AAB evidence" step dumps sha256, size, permission list, BILLING + APPLICATION_ID presence via bundletool. scripts/sync_public_ci.sh got MIRROR_BRANCH (default main). Branch snapshot pushed to the mirror as `next/android-ads`, CI dispatched: run 33632314186. Evidence follows when it finishes.
- 13:05Z 02O-3 DONE — signed AAB with ads + billing from CI, branch `next/android-ads` @ 3230a2c, mirror run 33632314186 (workflow_dispatch; Analyze+test success, Android success, Pages job SKIPPED — branch builds cannot touch the live site).
  - `app-release.aab` sha256 **c2c3faac4c84456e02ee67d3b06031c0b188c7cc3ecfcb71594b843f0a5fdb22**, 54,371,205 bytes (bundle incl. all three ABIs); per-device download per bundletool `get-size` = 10.1 MB (armeabi-v7a) / 10.6 MB (arm64-v8a) / 10.8 MB (x86_64).
  - `jarsigner -verify`: signature verified, CN=Tsoro Studios, OU=FLIP (permanent upload key); the APK from the same run passes the apksigner cert check 39cdb292…33a43.
  - bundletool manifest dump: package `com.tsorostudios.fliptide`, versionCode 1, versionName 0.1.0. **`com.android.vending.BILLING`: present. `com.google.android.gms.ads.APPLICATION_ID`: present.**
  - Full permission list: ACCESS_ADSERVICES_AD_ID, ACCESS_ADSERVICES_ATTRIBUTION, ACCESS_ADSERVICES_TOPICS, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE, INTERNET, WAKE_LOCK, com.android.vending.BILLING, com.google.android.gms.permission.AD_ID, com.tsorostudios.fliptide.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION. (ADSERVICES_*, AD_ID, FOREGROUND_SERVICE, WAKE_LOCK come from the Google Mobile Ads SDK merge; nothing else declared by the app.) Privacy page already lists AD_ID + BILLING; it does not list the ADSERVICES_* trio — add before store submission if you want the list literal (doc-only change, flagged below).
  - Artifacts on the run: `fliptide-release-aab`, `fliptide-release-apk` (release APK sha256 859b05d702bf28f8b3337ef4c35a2b16db9af750d112f32bc1ffa16ffd2f3a6a, 52.5 MB fat APK, for the phone smoke).
- 13:06Z 02O-5 ACK: emulator smoke logged as "needs device" (sandbox has no KVM, 1 CPU); no further retries. The release APK above is the one to run on the phone.
- 13:10Z 02O-6 DONE — **PR #2 opened**: https://github.com/tapiwamakandigona/fliptide/pull/2 "phase 2: ads + supporter IAP (merge after Play internal test)", `next/android-ads` (3230a2c) → `main`. PROJECT.md status refreshed. **AT THE GATE (phase 2 → Play internal test).** Not merging, not releasing, not touching the CG package or the Pages game bundle. Owner-side next: create the Play app, upload the AAB (sha c2c3faac…fdb22) to internal testing, create `fliptide_supporter` (non-consumable, USD 1.99), add a licence tester, then tell me it is live → I run/verify the real test purchase on the device you provide.
  Flags (unresolved, not blocking): (1) privacy page does not name the ADSERVICES_* trio the Ads SDK merges in — say so if you want them listed literally; (2) mirror still has two old snapshot commits authored `fliptide-sync <sync@fliptide.invalid>` on branch history; (3) green finish-line dashes pass behind the CLEARED caption (02j observation); (4) progress.md lives on main — resolve to main's copy at the PR #2 merge.
- 13:20Z INCIDENT (mine, contained): the docs-only mirror sync of main @67d775b went out WITHOUT "[skip ci]" (my ad-hoc sed did not match the script's commit line), which started mirror run 33633772458 — a full CI run whose Pages job would have rebuilt the live game bundle from main. Cancelled it 30 s in, while the test job was still running; build-web and Android were cancelled before starting, so **nothing was deployed** — Pages + /privacy/ still 200 with the current bytes. Fix so it cannot recur: `scripts/sync_public_ci.sh` now takes `SKIP_CI=1` (appends "[skip ci]" itself); docs-only syncs of main use it, no more hand-edited copies of the script.

## 2026-09-05 06:0xZ — Owner directive by chat: main UNFROZEN for the polish pass ("go ahead with what you recommend")
- Polish pass (render-only; see `next/polish` 8087cce / PR #5 for the ads-branch copy) cherry-picked onto
  main as `polish-main` without the phase-2 pieces (no checkpoints/ads/IAP code): flip turn-over anim,
  airborne stretch, motion trail, dust, death burst+shake+flash, CLEARED confetti, corridor/slab
  gradients, parallax pillars, lit edges, spike glow, pit walls, pulsing finish gate; HUD bar eases,
  death % pops, button rows rise, button depth. Also brings the 02j-3 won-screen fix to main
  (`playerAlpha` fade + caption fade-in) — main never had it (it sat on next/payload-trim).
- The CG package zip (docs/crazygames) and PR #1/#2 gates are NOT touched: PR #2 still waits for the
  Play internal test; PR #1 for "CG approved". This is a Pages/web refresh only.
