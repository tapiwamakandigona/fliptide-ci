# Public CI routing

## Verified configuration — 2026-09-05

The private `tapiwamakandigona/fliptide` repository remains the source of truth.
The existing public `tapiwamakandigona/fliptide-ci` mirror runs analysis/tests on
standard GitHub-hosted Ubuntu runners, which GitHub documents as free for public
repositories:
<https://docs.github.com/en/billing/concepts/product-billing/github-actions>.

- Private workflows `348116910` (CI) and `348320692` (Pages docs) are
  `disabled_manually`; both public-mirror workflows remain active.
  [GitHub API + managed CLI readback, 2026-09-05]
- No payment, spending-limit change, private-run retry, repository visibility
  change, or signing-key change was made. [scoped settings change, 2026-09-05]
- This configuration is specific to Fliptide. It does not establish that every
  project has been migrated, eliminate historical charges/storage, or install an
  automatic sync service.

## Each test-only change

1. Search the private source and progress before implementing. Work on an
   isolated task branch based on the appropriate phase branch, never frozen main.
2. Use the existing public sanitized snapshot and a separate task branch.
   Copy only inspected application/test changes needed for that task. Compare
   application, tests, dependency lockfiles, analyzer configuration, and workflow
   bytes with the private source.
3. **Never push private history to the public remote.** It contains signing
   material. Never copy `android/signing/`, `android/key.properties`, keystores,
   credentials, environment files, or unrelated private notes. Scan the exact
   changed files for credentials before each public push.
4. Open/update a public mirror pull request. Its existing `pull_request` path runs
   `flutter analyze` and the full `flutter test` suite with Flutter 3.44.9.
   Android and Pages jobs must be skipped for a test-only run.
5. Record the public commit and run URL in the private PR/progress. Do not call
   a disabled or historic failed private check successful. Do not weaken
   tests, acceptance criteria, or required checks to obtain a green badge.
6. A green public test run is not a release, device test, human playtest, or
   permission to merge phase-gated branches. Preserve both histories when a
   stacked branch eventually integrates.

## Deployment and signing guards

- Do not dispatch the existing full CI workflow merely to run tests: manual
  dispatch may also build signed Android artifacts.
- Do not push/merge public main for a maintenance test: main can publish the
  live Pages game.
- Approved signing still uses `UPLOAD_KEYSTORE_B64` / `KEY_PROPERTIES_B64`
  Actions secrets; no values belong in code, PR text, logs, or handoffs.
- Existing `scripts/sync_public_ci.sh` exports a snapshot but force-pushes its
  target branch and can overwrite history. Inspect it and get approval for
  destructive use; do not run it blindly for routine task-branch validation.
- These routing changes do not override CrazyGames approval, Play internal
  testing/purchase, Android timing, or human-play gates.
