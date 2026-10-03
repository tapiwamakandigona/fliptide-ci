# Saved ghost recovery — bounded iteration 3/6

## Source finding, not the phone's crash diagnosis

**VERIFIED source:** `Store.daily` calls `int.parse` on each comma-separated
saved ghost frame. `TitleScreen.build` reads today's record on boot, so a
non-numeric/truncated token can throw during title rendering. `getString`
also throws on a wrong-type stored value. No production frequency or relation
to the reported native startup failure is established.

## Plan before changing behavior

1. Add an immutable regression file covering valid replay roundtrip, invalid/
   wrong-type replay fallback, stable valid progress/supporter values and a
   title-screen boot with a corrupt ghost. Add no changes to old tests.
2. Run the existing public-mirror PR CI against unchanged application source.
   Expected red is a Dart parser failure, not a reproduction of the phone.
3. Read ghost data without a typed cast; accept only strictly ascending,
   nonnegative integer frames. Discard an invalid **ghost only**, never all
   preferences, achievements or purchases; do not splice a partial replay.
4. Keep the regression byte-identical. Re-run full analyzer/test CI.

Hard cap: two CI executions (expected-red plus green) for this task, one
evidence-based failure retry only if a concrete environment issue prevents
execution. No new workflow, skipped/weakened tests, dependency/version bump,
signing change, Android build or Play release.

## Acceptance

Valid ghost frames and existing progress round-trip unchanged. Malformed,
wrong-type, negative, duplicate and out-of-order replay frames produce an
empty in-memory ghost without throwing or rewriting storage. The real title
widget boots with a malformed stored replay. Existing full suite stays green.
The new feature remains false until actual CI evidence is inspected.

## Expected-red evidence

**VERIFIED:** public PR6 run34322320891 at `65e48f7` has clean analyzer;
**177 passed / seven new failures / three existing skips**. The six invalid
ghost cases and actual title boot fail on unchanged source. Exact failures:
`FormatException: Invalid radix-10 number (at character 1)` and
`type 'int' is not a subtype of type 'String?' in type cast`, plus acceptance
failures for invalid replay ordering. Existing tests pass. Android/Pages skipped.
Regression SHA256 `9ce64c2e8de0992890c061b786f57bdf28fc7e477f0e7f24735f7ff8a15c6085`.
[primary Actions logs, 2026-09-09]

## VERIFIED fix and limits

Full green run34322487346 at public
`6e3b79a9bb9cf3944d5def50c3de96c0c4eaec80`: clean analyzer,
**184 passed / three existing skips**. All eight new regressions pass with
the exact same SHA256. Existing tests/checks/workflow unchanged; Android and
Pages skipped. Source change is only the ghost read plus its safe parser.

Invalid replay data becomes an empty in-memory replay, without storage writes.
Valid best/attempts/win/stars/Supporter values and valid ghost frames are
preserved. No global exception swallowing, preference reset, schema change,
partial-replay salvage or added dependency. This is a checked source fix,
not part of the already-published 0.3.1 binary; no phone incident resolution.
[primary Actions logs and source diff, 2026-09-09]
