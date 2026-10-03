# Plan — October 2026 quality pass (Tsoro Studios)

Written 2026-10-03 at the owner's request so the plan survives outside any one
machine or session. The same file is committed to all three game repos. Live
status lives in each repo's `progress.md`, `PROJECT.md` and `features.json`;
this file is the map, not the odometer. Where this file and a repo's `DEMAND.md`
disagree, `DEMAND.md` wins — it is the owner's standing law for that repo.

## 1. The ask

Owner brief, 2026-10-02 17:20 UTC (verbatim):

> after you are done work on emberdelve and pyregrove and fliptide. Change anything and
> everything I'm giving you full artistic priviladge given that you can out do what was
> already there, also improving anything else and fixing everything else coz I want better
> graphics better character models better animations, controls etc etc. Just be a lowkey
> cool dev who knows what their doing and does it. Afteer your done cut release for github
> and playstore. Also if their are any useful prs utilize them

Read as: one quality pass per game — controls and game feel, animation, character
art, effects/UI, then bugs and rough edges — using whatever is good in the open PRs,
followed by a GitHub release per game and a Play Store release as far as Google
allows. Three games, in this order: **Emberdelve → Pyregrove → Fliptide**.

Later owner decisions (all UTC):

| When | Decision |
|---|---|
| 2026-10-03 01:38 | "go on everything else you recommended" → the narrow `marked_week_test` correction in Emberdelve is authorised; merging the reviewed PRs and cutting GitHub releases is a go. |
| 2026-10-03 02:12 | "yes to all and upload to production and stuff I wanna see in in the playstore and everything else decide for me I grant you all permission" → Play **production** is authorised. Judgement calls taken on the owner's behalf: 100 % rollout (small install base), no store-listing edits in this pass, the older Console service-account user is left in place. |
| 2026-10-03 03:42 | "put this plan of yours in the repos then just in case" → this file. |

## 2. Order, lanes, state at the time of writing

| # | Game | Repo | Code lane | Package | Where it stands (2026-10-03) |
|---|---|---|---|---|---|
| 1 | Emberdelve: Dice Roguelite | `tapiwamakandigona/emberdelve` (public) | `legacy/dice-builder` — `main` is the docs/Pages surface, never code | `com.tsorostudios.emberdelve` | v0.185.0 "Living Foes" live in production (versionCode 218). Pass in progress: PRs #112–#117 merged with green CI; #118, #119 next; then release 0.186.0. Draft PR #111 is a cherry-pick source (title fix already ported as #113; Forge offer readability, first-fight explanation, edge-to-edge insets, German listing still to review). PR #102 is a combat-visuals critique — a backlog source. |
| 2 | Pyregrove: Pixel Platformer | `tapiwamakandigona/pyregrove` (private; builds via the public CI mirror `pyregrove-ci`, see `docs/release.md`) | `main` | `com.tsorostudios.pyregrove` | 1.0.0-alpha.28 (versionCode 40) on Play internal + closed testing. Draft PR #9 `experimental/polish-loop` is **not** to be merged — cherry-pick what passes review. Pass not started. |
| 3 | Fliptide: One-Tap Gravity Run | `tapiwamakandigona/fliptide` (private) | `main` (unfrozen for polish since directive 2026-09-05a; the ads + supporter-IAP stack merged via PR #2 on 2026-09-10) | `com.tsorostudios.fliptide` | 0.4.0 "Soundtide" (versionCode 7) on Play internal + closed testing; no GitHub releases yet. Pass not started. |

All three pin Flutter **3.44.9 stable** in CI. Signed release builds exist only in CI
(`workflow_dispatch` → APK/AAB artifacts, upload-key certificate pinned). The keystore
is a CI secret and immutable: never regenerate keys, never touch `EXPECTED_CERT_SHA256`.

## 3. Rules that do not bend (summary — the full text is each repo's `DEMAND.md`)

- No analytics, telemetry, phone-home or dark patterns. No ads, except what a repo's own
  `DEMAND.md` sanctions: Fliptide's AdMob rewarded/interstitial units with the caps in
  directive 2026-09-02k and the $1.99 supporter purchase that removes every ad. Fliptide's
  web build stays at zero third-party requests.
- Public `docs/` is published surface (GitHub Pages). The hosted privacy policy URL is
  load-bearing for the store listings: never move, rename or rescope it.
- Commit identity: every commit, tag and release is the owner's, in the identity given by
  `DEMAND.md` directive 2026-09-02L; no assistant or agent attribution anywhere — not in
  commits, release notes, code headers or docs.
- Never force-push. Never `git pull`/merge across a rewritten history; fetch and reset as the
  repo's instructions say. Push at every milestone.
- Tests and verify commands are read-only unless the task *is* the check. A new test is seen
  red before it is seen green. `features.json` flips `passes` only with evidence that matches
  what the check prints now.
- Every merge lands on a head whose CI is fully green (Emberdelve: analyze+test **and** ios).
- One writer at a time. The only second pair of eyes is a read-only reviewer that writes its
  verdict and touches nothing else.
- Every claim in `progress.md` is labelled VERIFIED (command output, diff, artifact inspected)
  or ASSUMED.

## 4. The working loop (one iteration = one feature = one PR)

1. **Boot from files, on the lane branch**: `DEMAND.md` in full, `PROJECT.md`, `features.json`,
   the tail of `progress.md`, the newest `checkpoints/*.md` where present, `git log`, open PRs.
   Search before assuming anything is unbuilt.
2. **Toolchain + baseline**: Flutter 3.44.9; `flutter pub get`, `flutter analyze`, `flutter test`
   green before any change.
3. **Backlog** (built on the first iteration for a repo, then kept in `PROJECT.md` /
   `features.json`): rank by player-visible value × risk. Sources: the brief above, open
   features, the `DEMAND.md` backlog, PR critiques (#102 for Emberdelve, #9 for Pyregrove),
   real render captures from the repo's headless web harness. Preference order:
   controls/game feel → animation → character art → effects/UI → bugs.
4. **Act** on one feature on `feat/<slug>-<yyyymmdd>`; red test first where a test applies;
   keep it headless-testable.
5. **Verify**: analyzer clean, tests green, visual claims backed by a real capture labelled with
   how it was made (headless web ≠ device). Evidence into `features.json` and `progress.md`.
6. **PR against the lane**, CI green, merge when the lane rules allow (merge commit, PR title
   as message — the repos' setting), then the read-only review of the diff; its findings are
   the next iteration's first task.
7. **Record**: `progress.md` entry with a real timestamp; one commit per iteration.

Guards: at most 20 iterations per game in this pass; stop and report after two iterations
without a commit; on failure, one retry quoting the failure verbatim, then descope or
escalate. Budget rule: an iteration that merges a queue does not also build a feature.

## 5. Release procedure

**GitHub (every game)**: bump `pubspec.yaml` version + build number → run the CI workflow on
the lane (`workflow_dispatch`) → download the artifacts → confirm the signer output in the
CI log matches the pinned certificate → tag `vX.Y.Z` on the exact commit → GitHub release
with the sha256 of every asset in the body → re-download one asset **unauthenticated** and
compare the hash. A release exists when the tag exists and the asset re-downloads; "built
in CI" is not a release. Release notes are plain, player-facing, in the owner's voice.
Pyregrove builds through the public CI mirror (`scripts/sync_public_ci.sh`, androguard check
against the pinned certificate) exactly as `docs/release.md` describes.

**Google Play (Play Developer API, no browser)**: uploads go through a dedicated publishing
service account (Cloud project `tsoro-play-publisher`) that is a Play Console user with
release rights on all three apps. Its key lives outside every repo and is never committed,
logged or quoted. Per release: upload the hash-verified AAB, set the tracks, add release
notes in the listing's default language (`en-GB`; Emberdelve also has a `de-DE` listing),
validate the edit, then commit it. `versionCode` must exceed the highest code already on
any track (2026-10-03: Emberdelve 218, Pyregrove 40, Fliptide 7).

| Game | Tracks this pass | Why |
|---|---|---|
| Emberdelve | internal → closed (alpha) → **production, 100 %** in one edit | Production authorised 2026-10-03 02:12; the app is already in production. |
| Pyregrove | internal + closed only, for now | Google gates production behind a closed test with ≥ 12 opted-in testers for 14 continuous days, then an "Apply for access to production" form. On 2026-10-03 the Console showed 12 testers on day 5 → eligible around 2026-10-12. |
| Fliptide | internal + closed only, for now | Same gate; ≥ 12 testers confirmed, the day count was not displayed. |

When a game becomes eligible, the owner answers the Console's production application form
(questions about the closed test and the app's readiness — draft the answers from
`progress.md`, the owner submits). Follow-up check planned for 2026-10-13. No
store-listing, pricing or in-app-product edits in this pass.

## 6. Timeline (estimates, not promises)

- Emberdelve: merge queue and release 0.186.0 — 2026-10-03; production rollout the same day.
- Pyregrove: up to 20 hourly iterations → GitHub prerelease + Play internal/closed —
  through about 2026-10-04.
- Fliptide: up to 20 hourly iterations → first GitHub release + Play internal/closed —
  through about 2026-10-05.
- Production applications for Pyregrove and Fliptide: from 2026-10-12/13, owner-submitted.

## 7. If the automation stops

Anyone — the owner, a new builder — resumes from the repo alone:

1. Read this file, then `DEMAND.md` in full on the lane branch, `PROJECT.md`,
   `features.json`, the tail of `progress.md`, and the open PRs. Trust the files, not memory.
2. Set the commit identity from directive 2026-09-02L in your clone before the first commit.
3. Re-establish the green baseline (section 4, step 2), then continue the backlog one
   feature per iteration under the rules in section 3.
4. Release per section 5 when the backlog for the pass is done or the iteration cap is hit.
5. Keep `progress.md` honest: real timestamps, VERIFIED/ASSUMED labels, failures included.

The protocol behind this loop (state files, verification gate, read-only reviewer) is the
owner's Single-Agent Harness: https://github.com/tapiwamakandigona/subagent-toolkit
(`HARNESS.md`, `templates/`).
