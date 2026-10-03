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
