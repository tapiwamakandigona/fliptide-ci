# September 8 quality pass

## Iteration 10 — testing-candidate source and mirror

- Primary Play release read: highest uploaded code 3 / 0.2.0, internal and
  closed Alpha available. Both Production denial and one pre-existing
  tester-group publishing change are recorded; never bundle that blindly.
- Candidate `0.3.0+4`, with exact six-course/icon/menu/language release notes.
- Run unchanged analyzer, full tests and icon read-only check. Open private
  PR against actual shipping `next/android-ads`; preserve all prior fixes.
- Mirror only explicit game/build files into an isolated branch based on the
  existing public shipping mirror. No private Git history, signing/config
  secrets, business documents, progress logs or account reports copied.
- Keep existing CI workflow byte-for-byte: branch PR runs regression tests,
  no Pages deployment or signed build. After Emberdelve's Actions-dispatch
  403, do not retry with another credential or trigger; owner authorization
  or manual workflow dispatch is required for Android artifacts.

## Iteration 7 — accessible, lightweight translated front door

- French/Spanish/pt-BR first-session interface, based on the studio's
  verified Play language snapshot; no Fliptide audience data is available.
  Device locale, persisted manual override, English source fallback.
- Translate navigation, course prompt, new Shallows names/hints/story,
  result controls; dynamic legacy/store/share content may remain English.
  Scope note in language selector; never alter course codes or sim IDs.
- Small phones / enlarged text: scroll-safe title and content-sized buttons;
  map layout adapts columns and tile height without shrinking text.
- Existing decorative backdrop: cache dust and paints, paint directly from
  animation rather than rebuilding per frame, isolate repaint boundary;
  OS reduced-motion preference parks the controller completely.
- No physics, generator, monetization/consent or original test edits.
  Additive layout/locale/repaint checks and unchanged full suite green.

VERIFIED September 8: analyzer clean; 14 additive checks; 175 full-suite
passes / 3 original optional skips. All scoped checks passed first attempt.
Normal backdrop keeps the same widget/painter over 60 frames; reduced motion
has zero active frame callbacks. Physical-device visual/FPS checks pending.

Canonical harness main `4fe6eb4`, including v3.0.1, was cloned and read.
Single agent, one task per iteration, maximum 12 engineering iterations
across this studio pass. Existing tests and signing checks stay read-only.

## Source and owner authorization

**VERIFIED:** `main` at `6a10c37` has the campaign, but the shipped Android
line is `next/android-ads` at `c882f09` (0.2.0+3). The quality worktree was
fast-forwarded to that descendant before edits, preserving Supporter,
consent, checkpoint and course-dialog fixes already in the Play build.
Do not mistake an old open PR for work absent from that shipping line.

The September 8 owner request authorizes game improvements and Play updates,
superseding old development freezes for this pass. It does not certify a
real purchase test, production access, phone performance, or a release.

## Ordered scope

1. **App identity:** original gravity-flip launcher art using the existing
   navy/gold/red palette. Legacy density icons, adaptive foreground/background,
   Android 13 monochrome icon, round icon and web icons. Deterministic generator
   and XML/dimension checks; no new runtime dependency.
2. **Authored teaching courses:** replace only the first tide's random chunk
   ordering with deliberate teach → repeat → combine obstacle sequences and
   short story/hint copy. Keep all saved level ids, Daily/shared-code version
   1 output and the other campaign levels stable. Verify actual solver replay.
3. **Low-end menu cost:** do not run a course solver in a tile widget's build.
   Use metadata-only duration estimates; generate only the selected course.
   Respect reduced motion and fix cramped menu layout without scaling away
   usable controls. Record measured desktop CPU, not assumed phone FPS.
4. **Distinct runners:** geometry/silhouette choices, not colour swaps, if
   this release pass has room after higher-priority game and release work.

## Release gates

Original suite unchanged/green, new regressions green, signed bundle package/
version/certificate verified, real device limitations explicit, same existing
Play track unless production access is actually granted.

## Iteration 4 — deliberate Shallows

Teach one idea at a time with campaign-only, explicit segment order. Keep the
version-1 generator untouched; selected campaign levels take a separate
authored path. Stable ids and earned stars remain. Old per-level ghosts
cannot be replayed against changed geometry: use a new record revision only
for the six revised courses, retaining old records rather than deleting them.
Share a campaign level link, not the generic seed code (which does not encode
campaign-specific speed/length). Add solver and comfortable reaction-policy
replays for every authored course. Core physics and all earlier tests frozen.
