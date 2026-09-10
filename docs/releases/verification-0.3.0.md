# VERIFIED First Light testing candidate — 2026-09-08

Private source `28899e7`, [PR #11](https://github.com/tapiwamakandigona/fliptide/pull/11)
to shipping `next/android-ads`. Explicit public source-only mirror
`310634d35841fdbaed9d14cbad602551ff2ca413`,
[PR #4](https://github.com/tapiwamakandigona/fliptide-ci/pull/4).
All 114 allowlisted files byte-identical; no private history, business docs,
keys or workflow changes copied. Private paid Actions remain disabled.

## Checks and artifacts

Analyzer clean, 175 tests / 3 original optional skips, 16 deterministic
launcher rasters/resource contracts verified. Original checks preserved.
Existing public signed [CI run 34245492322](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34245492322)
succeeded via explicitly authorized PAT on the exact mirror SHA. Pages job
was skipped; no live web deployment was made.

Downloaded ZIP digests matched GitHub. Independent Android apksigner,
JDK jarsigner, PKCS7 certificate pins and bundletool validation/manifest
checks passed: `com.tsorostudios.fliptide`, `0.3.0`, code 4, minSdk24,
targetSdk36, non-debuggable. Existing billing/AdMob manifest checks passed.

Permanent upload signer:
`39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43`.

| File | Bytes | SHA256 |
|---|---:|---|
| app-release.aab | 56993350 | `b9567dd97ff4b8457694ba840ef5ac8b59a001729d03f4d9541146f6e4220448` |
| app-release.apk | 55705436 | `d29063fb62cd74681fcdfb574e56ee21baa439a5ec8a9420eeafb0037227896c` |

## Play state

VERIFIED after save/publish and track reload: **internal testing —
4 (0.3.0) — Available to internal testers**. Preview Ready to release,
zero newly unsupported devices. Production access remains denied.

Same bundle was prepared for closed Alpha, with 100% of that testing track.
**It is saved, NOT submitted**: the console groups the release with a
pre-existing unsubmitted Google Groups tester-roster change. Do not submit
that roster change without resolving its scope. Internal testing is live.

The original 512px store icon was uploaded, the previous slot replaced
(asset library preserved), and original listing text/feature graphic/eight
screenshots preserved. The new icon was honestly labelled AI-created/edited.
Icon only submitted, initially in review with quick checks pending.
Final primary readback: **Submission activity — submission3, Store Listing,
Published**, and the default listing editor is **Live** without pending
listing changes. Saved Alpha/roster changes remain outside review. This
verifies Console publication; no claim of global client-cache propagation.

Reopened the listing editor after save/submission and retrieved its served
512px icon: pixel-by-pixel RGBA equality to source was verified. Source
PNG SHA256 `15eab6e4136c4ad970b0830e4e143b2e7c5e04833ac1efca03eb034eb827d3b8`.
Final live editor serves the same asset URL. The main listing's three text fields and empty video value remained
unchanged, as did the feature graphic and eight screenshot assets.

## GitHub download readback

[v0.3.0 prerelease](https://github.com/tapiwamakandigona/fliptide-ci/releases/tag/v0.3.0)
targets exact mirror `310634d`, not latest stable. Both published binaries
and `fliptide-SHA256SUMS` were re-downloaded from the release; SHA256/byte
counts match the independently verified files above.

## Still open

F3 Android restart timings, F7 human/live-Pages end-to-end, installed icon
review, physical low-end FPS, real Supporter purchase/restore remain open.
Smaller host menu workload is not measured phone FPS. No public production
launch or new Pyregrove/Fliptide character roster is implied.
