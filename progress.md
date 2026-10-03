# progress.md — Fliptide

Append-only session log. Every claim is labelled VERIFIED (command output,
diff or artifact inspected) or ASSUMED.

**Rotation (2026-10-03).** The previous log reached 87,538 bytes, past the
64 KiB rotation threshold, and was moved byte-for-byte to
`archive/progress-segment-1.md` (SHA-256
`78862e80cf4fa313010fcbf881c76414a4bf08ea0a77f418a9b7c7ab84d056db`, 87,538
bytes). Any older reference to "progress.md" for entries before this date
means that archive file.

## 2026-10-03 15:45 UTC — October 2026 quality pass starts

- Owner direction: brief of 2026-10-02 (`PLAN.md` §1); 14:03 UTC "finish
  coding and producing the apk"; 14:33 UTC "no need for playstore now just
  work on the games" → no Play/AdMob/CrazyGames action this pass.
- VERIFIED: rotation above — `git mv progress.md archive/progress-segment-1.md`;
  `sha256sum` before and after both
  `78862e80cf4fa313010fcbf881c76414a4bf08ea0a77f418a9b7c7ab84d056db`.
- VERIFIED baseline on main 2560ffb (Flutter 3.44.9 / Dart 3.12.2):
  `flutter analyze` → No issues found; `flutter test` → 197 passed /
  3 skipped ("All tests passed!").
- Added the "October 2026 quality pass" section to `PROJECT.md` (decisions,
  version plan 0.5.0+9, ranked backlog) and three new feature objects
  (`F-OCT-TIDELIGHT-20261003`, `F-OCT-SPARK-GAZE-20261003`,
  `F-OCT-PACKAGE-0.5.0`, all `passes: false`). Existing feature objects
  untouched.
- VERIFIED: `feat/tidelight-0.4.1` (2cd4780) is not merged into main; its
  test `test/tidelight_scenery_test.dart` fails on main as expected
  ("Error when reading 'lib/game/scenery.dart': No such file or directory") —
  the red half of red→green for iteration 1.

## 2026-10-03 15:50 UTC — Iteration 1: Tidelight scenery integrated

- Source: unmerged `feat/tidelight-0.4.1` (2cd4780, built once on the mirror
  as 0.4.1+8, never shipped). Reviewed the diff: render-only (new
  `lib/game/scenery.dart`, slabs → crust + scenery and a cached radial glow
  under the player in `lib/game/flip_game.dart`), no sim change, no assets.
  Cherry-picked with `-x` onto main, then reverted the version bump to
  0.4.0+7 (packaging owns the version) and dropped `docs/releases/v0.4.1.md`
  (its notes fold into 0.5.0).
- VERIFIED red→green: `test/tidelight_scenery_test.dart` fails to compile on
  main ("Error when reading 'lib/game/scenery.dart': No such file or
  directory"); on the branch 4 passed.
- VERIFIED gate: `flutter analyze` No issues found; `flutter test` 201 passed /
  3 skipped. `lib/sim` diff empty; no `Random` in scenery.dart.
- VERIFIED payload: `flutter build web --release --wasm --no-wasm-dry-run` +
  `scripts/prune_web.sh`: per-player gzip -9 upper bounds 3.64 MB (skwasm) /
  4.96 MB (CanvasKit) — inside the 6 MB budget.
- VERIFIED captures (headless Chromium, not a device):
  `docs/visual/2026-10-03/tidelight_portrait_run.png`,
  `tidelight_portrait_ceiling.png`, `tidelight_landscape_run.png` — sky with
  moon and ridges above the ceiling, sea below the floor in 390×844 portrait,
  crust only in 1280×720 landscape; 0 page errors.
- ASSUMED: frame cost on a real phone (not measured; ~20 extra draw calls per
  the original branch notes).

## 2026-10-03 15:58 UTC — Iteration 2: the spark watches the danger

- New `lib/game/gaze.dart`: `sparkGaze(course, x, side)` — a pure read of
  the course for the nearest spike, pit or raised wall on the surface the
  spark runs on, within 4 columns of its front edge; alarm 0..1 rises as it
  closes in. Render-only: the sim never reads it.
- `lib/game/flip_game.dart`: eased alarm (fast up, slow down); eyes widen up
  to +28 %, pupils slide forward and towards the surface for spikes/pits,
  no blinking while alarmed, a small "o" mouth at high alarm. The creature
  draw path now reuses six cached `Paint`s instead of allocating seven per
  call.
- VERIFIED red→green (`test/spark_gaze_test.dart`, 8 tests): on main the
  file fails to compile ("Error when reading 'lib/game/gaze.dart'"); with
  gaze.dart but the old draw path the Paint scan fails ("Expected: <0>
  Actual: <7>"); the real-run test against main's flip_game.dart fails ("The
  getter 'sparkAlarm' isn't defined"). After the change: 8 passed.
- VERIFIED gate: `flutter analyze` No issues found; `flutter test` 209
  passed / 3 skipped. `lib/sim` diff empty.
- VERIFIED capture (headless Chromium, not a device):
  `docs/visual/2026-10-03/spark_gaze_calm_vs_alarmed.png` — calm at the
  start of Tide 1·1 vs wide eyes, pupils down-forward and the mouth opening
  just before the first spikes; 0 page errors.
- ASSUMED: web payload change negligible (Dart code only, no assets; not
  re-measured this iteration — 3.64 / 4.96 MB gz measured in iteration 1).

## 2026-10-03 16:06 UTC — Iteration 3: near misses

- Correction: the two entries above were first written with estimated
  times (16:05 and 16:30 UTC); I replaced them with the real commit times
  (Tidelight bcd1f25 at 15:50, gaze c92a674 at ~15:58 UTC).
- `lib/game/gaze.dart`: `Gaze` now carries the hazard column; new
  `NearMissTracker` arms when the raw alarm reaches 0.65 (≈ 1.4 columns, the
  latest a flip still reliably clears a spike at gravity 58 / speed 9) and
  fires once when the back edge clears that column; a row counts once.
- `lib/game/flip_game.dart`: on a near miss, 16 round sparks stream back
  from the spark and its glow flares for 0.4 s; count resets per attempt
  and on checkpoint resume. No audio, no assets, no sim change.
- Process note: the feature object `F-OCT-NEAR-MISS-20261003` was drafted
  alongside the code and committed (1e000c0) before the implementation
  commit.
- VERIFIED red→green (`test/near_miss_test.dart`, 7 tests): before the
  change it fails to compile ("The getter 'nearMisses' isn't defined for the
  type 'FlipGame'", "Method not found: 'NearMissTracker'"); after: 7 passed —
  incl. real games: a flip at alarm 0.7 over a floor spike survives with 1
  near miss; a flip at 0.2 survives with 0; no flip dies with 0.
- VERIFIED gate: `flutter analyze` No issues found; `flutter test` 216
  passed / 3 skipped. `lib/sim` and `assets` diff empty.
- VERIFIED capture (headless Flutter render via `Picture.toImage` from a
  throwaway, uncommitted test; not a device):
  `docs/visual/2026-10-03/near_miss_burst.png` — 2 and 9 frames after the
  near miss: glow flare on the spark, sparks trailing behind.
- ASSUMED: how it feels at speed on a phone (no device).

## 2026-10-03 16:10 UTC — Packaging: 0.5.0+9

- `pubspec.yaml` 0.4.0+7 → **0.5.0+9** (9 > 8, the never-shipped mirror
  build of 0.4.1, and > 7, the highest code on any Play track). No in-game
  version label exists (searched `lib/`, `web/index.html`,
  `web/manifest.json`: only code comments mention versions).
- `docs/releases/v0.5.0.md`: player-facing notes + VERIFIED source/scope
  section; tester note 282 chars. Build hashes to be added at release time.
- VERIFIED: `git diff --stat 2560ffb origin/main -- lib/sim assets android
  pubspec.yaml pubspec.lock` is empty (0.4.0 → pre-bump main), so "same
  courses, codes, ads/IAP, no new libraries/permissions" holds.
- VERIFIED gate: `flutter analyze` No issues found; `flutter test` 216
  passed / 3 skipped.
- Not done in this pass (by scope): tag, signed build, GitHub release; no
  Play/AdMob/CrazyGames action (owner hold 14:33 UTC).

## 2026-10-03 16:28 UTC — Release review and pre-release fixes

- An independent read-only review of `2560ffb..0460b25` returned **PASS**:
  0 blocking, 0 major, 3 minor, 5 nits. Merge trees match the PR heads, the
  cherry-pick is the same patch as `2cd4780`, nothing changed under
  `lib/sim`, `assets`, `android`, `web`, `ios`, `.github` or
  `pubspec.lock`, and every claim in the notes is backed by code.
- Fixed on `fix/zero-size-scenery-20261003` (render-only):
  - `Scenery.render` returns early when the view or tile is zero. Before
    this, a zero-width view made the wave length 0, and `(0/0).ceil()`
    threw inside `FlipGame.render`. 0.4.0 did not throw there.
  - The `_confetti` doc comment is back on `_confetti`; `_nearBurst` keeps
    its own.
  - The notes now say what wide screens show: the corridor keeps its solid
    edges and the night beyond them stays dark.
- Correction to the 16:06 entry above: the near-miss *count* resets with
  each attempt (`_reset()`). A checkpoint resume resets the tracker and the
  flare, not the count. That is deliberate, since a resume is not a retry.
- VERIFIED red→green:
  - Before the fix, both new tests in `test/tidelight_scenery_test.dart`
    ("zero-size viewport (hidden embed): no exception, then recovers" and
    "full game survives a zero-size viewport and a resize back") failed
    with "Unsupported operation: Infinity or NaN toInt" at
    `scenery.dart 188:39 Scenery._rebuild`. After the fix both pass.
  - `test/near_miss_test.dart` "the count resets with each attempt" passes
    before and after; it pins behaviour that already existed. The `run`
    helper was split into `start` + `_play` without changing what it does.
- VERIFIED gate (Flutter 3.44.9): `flutter analyze` No issues found;
  `flutter test` 219 passed / 3 skipped.
- Remaining review notes are backlogged in `PROJECT.md` (dark band beyond
  the crust on wide screens, near-miss edge cases, win-fade freeze, test
  gaps for the drawing, small per-frame allocations).
- ASSUMED: nothing here changes how it looks on a phone; the guard only
  affects zero-size views.

## 2026-10-03 16:51 UTC — Release v0.5.0

- Mirror: I synced private `35fa2c5` to `tapiwamakandigona/fliptide-ci` as
  an ordinary commit through mirror PR #8 (tree snapshot, signing material
  stripped, `MIRROR.md` regenerated, no force-push). PR CI run 37137023251:
  "No issues found!", "219 tests passed, 3 skipped." Squash-merged as
  mirror main `7367295`. Mirror PR #7 (the 0.4.1 sync) is superseded.
- The GitHub integration I used cannot start the workflow by hand
  (`workflow_dispatch` → HTTP 403 "Resource not accessible by
  integration"). The signed build is therefore the push-to-main run
  37137193722, which also redeployed the Pages playtest.
- VERIFIED (run 37137193722, all jobs success): "No issues found! (ran in
  15.4s)"; "219 tests passed, 3 skipped."; versionCode 9, versionName
  0.5.0; V2 signer certificate SHA-256 equals the pin `39cdb292…3a43`.
- VERIFIED (downloaded artifacts, checked on their own): APK and AAB have
  the right package and version, are not debuggable, and are signed by the
  pinned key. Hashes and sizes are in `docs/releases/v0.5.0.md`.
- VERIFIED: GitHub Release v0.5.0 (pre-release, not "Latest") on the mirror
  at `7367295` carries the APK, AAB, web zip and `fliptide-SHA256SUMS`,
  with each sha256 in the body. I downloaded all four again without
  authentication and `sha256sum -c` passed. Private lightweight tag
  `v0.5.0` → `35fa2c5`, the same convention as v0.4.0.
- VERIFIED web: Pages serves the release zip byte for byte. Per-player gzip
  upper bounds are 3.64 MB (skwasm) and 4.96 MB (CanvasKit). Live throttled
  first frame at 3.04 s (headless Chromium, skwasm). A solver run of Daily
  #276 cleared with 0 page errors.
- ASSUMED / not verified: feel and frame time on a real phone. The ~3.21 MB
  live transfer is an estimate from re-compressed bodies. Nothing was
  uploaded to Google Play (hold).

## 2026-10-03 17:24 UTC — Review findings 1: near-miss edge cases

- Branch `fix/near-miss-edges-20261003` from main `fb31113`. Render-only:
  `lib/game/gaze.dart` and two call sites in `lib/game/flip_game.dart`.
- A row of hazards now fires its one near miss only when the back edge is
  past the row's last column. `Gaze` carries `endCol`, the contiguous run of
  hazard columns on that surface, and the tracker waits for `endCol + 1`.
- Landing on a raised block near its edge no longer counts as a wall near
  miss. Two parts: `sparkGaze` now takes the spark's `y`, so a block it
  stands on or drops onto is not a wall; and the sim lets a falling spark
  dip below a block top and then pop up onto it, so the tracker also drops
  an armed wall once the spark stands on that surface over the wall's
  columns (a side hit would have been a death, so it can only be on top).
- VERIFIED red first, against main's `lib/game`: the spike-row test failed
  with "Expected: a value greater than or equal to <18.0> Actual:
  <15.099999999999946>"; the block-landing test failed with "Expected: <0>
  Actual: <1>"; the API tests failed to compile ("Too many positional
  arguments: 3 allowed, but 4 found.", "No named parameter with the name
  'y'.", "The getter 'endCol' isn't defined for the type 'Gaze'."). After
  the change `test/near_miss_test.dart`: 15 passed.
- VERIFIED existing behaviour kept: early flip 0, death 0, per-attempt
  reset (existing tests, unchanged), and a new test that a checkpoint
  resume keeps the count, which also passes on the old code.
- VERIFIED found while testing: a flip from the floor in front of a 1-tall
  block survives at alarm 0.5/0.55/0.6 and dies at 0.62/0.65/0.7 (on this
  branch; 0.7 also died on main). With the 0.65 threshold, a wall near miss
  from a fresh flip cannot happen today. I did not change the threshold.
  The feature's acceptance (written before the code) asks that such a
  flip "still counts once"; that holds in the tracker (unit test: armed on
  a floor wall, then past the row on the ceiling fires once), not in a
  real run, because the run dies first.
- VERIFIED gate (Flutter 3.44.9): `flutter analyze` No issues found!;
  `flutter test` 226 passed / 3 skipped (baseline 219 / 3).
  `git diff --stat origin/main -- lib/sim assets android ios web .github
  pubspec.yaml pubspec.lock` is empty.
- `dart format` was run on `lib/game/gaze.dart`. `flip_game.dart` and
  `test/near_miss_test.dart` were not formatted on main either; formatting
  them now would rewrap 300+ unrelated lines, so I left their style as is.
- ASSUMED: how it feels on a phone (no device run).

## 2026-10-03 17:28 UTC — Review findings 2: the win fade no longer freezes the face

- Branch `fix/win-fade-ease-20261003` from main `b693c17`. Render-only.
- I chose to keep easing through the fade, not to snap to a calm spark at
  the win (a snap would pop while the sprite is still visible). The easing
  lines moved unchanged into `FlipGame._easeFace(dt, gaze)`. The won branch
  of `update()` now calls it with `Gaze.calm`, so a near-miss flare decays
  on its 0.4 s clock and the eyes relax at rate 5, as they do once danger
  is behind. The fade itself (`kWonFadeS`, `playerAlpha`) is unchanged.
- New `test/support/recording_canvas.dart`: a canvas that records calls
  (paint colours snapshotted at call time) so tests can read what is
  drawn. Not a test file; the suite count does not include it.
- VERIFIED red first on main: "Expected: a numeric value within
  <0.000001> of <0.6666666666666669> Actual: <0.7083333333333335> ... flare
  at fade frame 1". In a throwaway copy with the flare check off, the alarm
  check failed too: "Expected: a numeric value within <1e-9> of
  <0.06210139646145423> Actual: <0.06749825929487792> ... alarm at fade
  frame 1". After: `test/near_miss_test.dart` 16 passed.
- VERIFIED gate (Flutter 3.44.9): `flutter analyze` No issues found!;
  `flutter test` 227 passed / 3 skipped. No diff under `lib/sim`, assets,
  platform folders, `.github` or pubspec files.
- ASSUMED: the change is too short to notice on a phone (the fade is 0.15 s);
  it removes a freeze, nothing more.

## 2026-10-03 17:35 UTC — Review findings 3: scenery builds nothing per frame

- Branch `fix/scenery-no-alloc-20261003` from main `d99d3cf`. Only
  `lib/game/scenery.dart` changes (render-only).
- Sky and sea rects are now built on resize. The star views are built once,
  one per bucket and per count. The lighthouse list literal is replaced by
  two calls to `_drawLighthouse`. The moon glint fills a reused buffer and
  draws its segments in one `drawRawPoints(PointMode.lines)` call, where
  it used to make five `drawLine` calls with new `Offset`s.
- VERIFIED red first on main:
  - The new identity test, which renders the same state twice through a
    recording fake canvas, failed with "Expected: empty Actual: [ 'call 1
    clipRect arg 0 Rect', 'call 2 drawRect arg 0 Rect', 'call 3
    drawRawPoints arg 1 _Float32ArrayView', … 'call 36 drawLine arg 1
    Offset' ] objects built again for the same state".
  - The canvas cannot see the list literal, so a source scan of the render
    path pins that too. It failed with "Expected: empty Actual: [
    'sublistView(', 'Rect.from', 'Rect.from', 'Rect.from', 'Rect.from',
    'Offset(', 'Offset(', 'in [' ]".
  - After: `test/tidelight_scenery_test.dart` 8 passed.
- VERIFIED the picture is unchanged. A throwaway test (not committed) drew
  main's `Scenery` and the new one with `Picture.toImage` for 120 states
  (three sizes, 40 camera/clock values each): 0 bytes differed. A copy of
  main's `Scenery` with the glint removed differed in all 120, so the
  comparison does see the glint.
- VERIFIED gate (Flutter 3.44.9): `flutter analyze` No issues found!;
  `flutter test` 229 passed / 3 skipped. No diff under `lib/sim`, assets,
  platform folders, `.github` or pubspec files.
- ASSUMED: the saving is small (a handful of short-lived objects per
  frame); I did not measure frame time on a phone.
- Retry note: the gate on the first commit (`adde15b`) failed: "info •
  Statements in an if should be enclosed in a block. Try wrapping the
  statement in a block • test/tidelight_scenery_test.dart:180:15 •
  curly_braces_in_flow_control_structures". `dart format` had wrapped a
  one-line `if` in the new test after my earlier analyzer run. I added the
  braces; the test logic is the same. I also corrected this entry's time to
  the real commit time.

## 2026-10-03 17:44 UTC — Review findings 4: drawing tests for the face, burst and flare

- Branch `fix/spark-drawing-tests-20261003` from main `908d5bc`. Tests and
  docs only; no file under `lib/` changes.
- New `test/spark_drawing_test.dart`, 8 tests. They read what
  `FlipGame.render` hands the recording canvas in real 390×844 runs, and
  each test makes one assertion: a list of mismatches must be empty.
  - The alarm sweep covers calm, alarmed and open-mouthed frames.
  - Eye radius is `t·0.11·(1+0.28a)`.
  - Pupils sit `r·(0.35+0.12a)` forward and `r·(0.3a−0.1)` towards a floor
    spike.
  - The "o" mouth is drawn only above 0.55 and grows with the alarm.
  - A near miss draws exactly 16 round sparks, and 6 frames later all of
    them are more than half a tile behind the spark's back edge.
  - The glow is scaled 1.6× on the near-miss frame and decays linearly to
    none by frame 24 (0.4 s at 60 fps).
- VERIFIED green on main (8 passed). Then VERIFIED each test red once
  against a broken renderer. A script applied each break, ran the file and
  restored the source; `git diff --stat origin/main -- lib` was empty
  afterwards. Failure text (first lines):
  - B1, eye growth 0.28 → 0, fails "eye size": "Expected: empty Actual:
    [ 'alarm 0.0038369922489196718: r 4.766666666666667', …".
  - B2, pupil forward 0.12 → 0, fails "pupils slide forward": "'alarm
    0.0038369922489196718: dx 1.6701257203125408', …".
  - B3, pupil drop 0.3 → 0, fails "pupils drop towards the spike": "'alarm
    0.0038369922489196718: dy -0.47717877723221136', …".
  - B4, mouth threshold 0.55 → 0.7, fails "mouth": "'alarm
    0.5654831848410808: no mouth', …".
  - B5, burst 16 → 12, fails "bursts exactly 16 round sparks" ("Expected:
    <16> Actual: <12>") and "streams back" ("['12 sparks']").
  - B6, burst aimed forwards, fails "streams back": "'spark at
    3.555558017047275 px from the back edge', …".
  - B7, `kNearMissS` 0.4 → 0.6, fails "glow flares": "'frame 1:
    0.9722222222222221', …".
  - B8, alarm capped at 0.5 in `gaze.dart`, fails "the sweep covers":
    "['last frame not alarmed: 0.4766666486788816', 'no frame above 0.6']".
- The setup checks (the run dies / the near miss happens, two eyes, two
  pupils) are preconditions, not assertions about the drawing. I did not
  break each of them on purpose; B8 did trip the near-miss setup check.
- VERIFIED gate (Flutter 3.44.9): `flutter analyze` No issues found!;
  `flutter test` 237 passed / 3 skipped.
- With this, the four 0.5.0 review findings in PROJECT.md are closed; see
  the status paragraph there.
