# Visual trail clock — verified source and local web build

## Scope

Trail sampling and ageing now use the existing fixed simulation clock;
rendering only reads the samples. Keep five samples, taken every second
simulation frame, aligned with the previous state used by the interpolated
player. Stretch easing uses an exponential rather than linearly clamped
blend factor. No simulation, course, billing or release-gate changes.

## VERIFIED evidence

- Based on main `f9d88c2c5d55c6fe1d65bd9e727bf96441356aec`, not the initial
  `next/polish` patch base. Main already has the polish as `af3b69d`; the
  distinct ads/checkpoint branch and open PRs remain untouched.
  [managed Git log/diff and PR API, 2026-09-05]
- Baseline instrumentation adds only a read-only snapshot getter. Two new
  tests fail on the original renderer: eight paint-only calls replace every
  sample with the same newest point, and identical elapsed time produces
  different history at different update/render rates.
  [baseline regression output, 2026-09-05]
- The same test bytes pass after the production fix: paint-only calls leave
  trail/sim unchanged; **30/60/120Hz**, each covering **0.2s**, give identical
  bounded sample positions/ages and simulation/input history. Samples do not
  lead the interpolated player. [fixed regression output, 2026-09-05]
- `flutter analyze --no-pub`: **No issues found!** Full
  `flutter test --no-pub --reporter expanded`: **71 passed**, including the
  existing daily-course solvability sweep. [local check outputs, 2026-09-05]
- `flutter build web --wasm --release --no-pub`: exit **0**. The existing
  CupertinoIcons expected-font warning remains, not suppressed.
  [release web build output, 2026-09-05]
- Build hashes:
  - JS `ec253fdd63c1e62daf27d4a3ab65c588bda1f77981f5adde3f4938c97ac55d4b`;
  - Wasm `92558d43deff4c95658abd5d8ce08f0c78bd85d417029b2cb09ea02cd82b18fa`.
  [built file SHA-256 digests, 2026-09-05]
- Local built game in Chromium: at **1280×720**, solver autoplay reached
  `won:1`; at **390×844**, normal play reached `dead:1:5`, then a centre tap
  after the guard reached `running:2`. Both had zero page exceptions and only
  local-host requests; external requests were blocked but none were attempted.
  [browser state bridge and network events, 2026-09-05]

## Limitations and failed check preserved

The first browser readiness wait failed:
`Page.wait_for_selector: Timeout 45000ms exceeded.`
Its locator resolved to a hidden `flt-glass-pane`. Direct inspection showed
the host has no layout box; its shadow canvas paints. One corrected run used
the actual Flutter first-frame event plus observed shadow canvas and passed
the unchanged gameplay assertions. Game source/checks were not altered for it.

Screenshots were captured, not holistically visually reviewed. These local
checks do not establish human playthrough, Android restart timing, phone FPS,
battery savings, deployment payload budgets or Play purchase/restore.

Root `features.json`, its open **F3/F7**, existing tests, simulation, course
generation, dependencies, Android/signing, public mirrors, CrazyGames package,
Pages and store state remain untouched. No tag or release is part of this fix.
