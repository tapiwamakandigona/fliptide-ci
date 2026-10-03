# Native startup incident — September 9

## Scope

The owner reports that the update still stops before any game screen and
requests a fix followed by a Play update. Preserve saves and the permanent
signer; publish a verified candidate to the existing internal and closed
testing tracks, not production. Other game/sharing work is paused.

## VERIFIED native failure

The exact shipped code5 APK, SHA256
`16464b50d482b0e25d8870e76bba6562369e0a67537185fd322bb3a50ba7fd48`,
was downloaded, checksum-checked, installed and launched on stock Android15
(API35, x86_64) by
[CI34338978110](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34338978110).
The process exited before Flutter started:

```text
FATAL EXCEPTION: main
Process: com.tsorostudios.fliptide
Unable to get provider androidx.startup.InitializationProvider
Failed to create an instance of androidx.work.impl.WorkDatabase
```

The shipped DEX contains `WorkDatabase_Impl` but no constructor. Disassembly
of its caller shows `Class.forName(...).newInstance()`; that reflective
construction requires a public no-argument constructor. R8 preserved the
class name but removed the constructor. This is actual native app evidence,
not a static manifest test or a speculative GPU explanation.
[downloaded code5 APK/AAB DEX, R8 mapping and native CI log, 2026-09-09]

## Comparison with the other games

- The actual ARM64 Flutter engine library is byte-identical in Fliptide
  code5 and Emberdelve code209. Both include the renderer opt-out.
- Fliptide includes AdMob and its WorkManager startup dependency; the other
  two games have no AdMob startup path.
- Fliptide uses AGP9.0.1 and optimized R8 without app-specific keep rules.
  Emberdelve/Pyregrove use AGP8.9.2; Emberdelve has additional reflection rules.
  These differences guided the diagnostic; they alone were not a diagnosis.
- Launcher/Kotlin code exists. All native ABI files and local ZIP/ELF
  alignments passed inspection. No reason established to change minSdk,
  renderer, ABI support, Flutter, Kotlin or AGP.
[primary source and downloaded artifacts, 2026-09-09]

## Narrow fix and immutable verification plan

Retain only `WorkDatabase_Impl` and its public no-argument constructor using
an app ProGuard rule. Leave minification/resource shrinking enabled. Package
as **0.3.2+6**; the source already includes the separately checked ghost-data
recovery from PR16. No gameplay, save schema, SDK or existing test changes.

1. Add an artifact-level DEX assertion; prove it fails for code5 APK/AAB.
2. Run the unchanged public release CI: full analyzer/tests, same-key APK/AAB.
3. Assert the constructor exists in both new artifacts; independently check
   package, version, signatures, flags, ZIP/ELF and bundle validity.
4. Run the byte-identical native launch script from `2314e6b` against the new
   APK: three cold launches remain alive and foreground. Inspect native
   crash logs and screen evidence; extend runtime coverage additively.
5. Publish only that exact checked bundle to both current testing tracks,
   checking support changes and distinguishing review from availability.

One corrective build retry only. No paid/private CI, no production,
CrazyGames/Pages, key regeneration, uninstall, storage clear or schedule.

## VERIFIED packaged and native result

The original release workflow
[CI34339802836](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34339802836)
built public source `5d0114d2e5ff71b82792192fa7dcf65a05b6e1b7`
(private source `6af6248`): analyzer clean, **184 passed / 3 existing skips**,
signed APK and AAB. Pages was skipped. Every original test, application
source, dependency lockfile and existing CI workflow was unchanged from the
checked ghost-recovery parent. [primary completed CI job log and managed diffs, 2026-09-09]

| Artifact | Bytes | SHA256 |
|---|---:|---|
| APK | 55,738,244 | `186f90ab8bb7f19dc3f114ebf565ad0d7d568d6c3c5e4ee21c552214bdaf6ac1` |
| AAB | 57,056,543 | `e8a2bca2711f4b89c6b47ec789bd91b1edfbb7b1a96d8965ecfbf6b76eb85159` |

Both pass the identical DEX assertion that fails on code5: the public
`WorkDatabase_Impl.<init>()V` exists with executable code. APK v2 verification
and AAB certificate inspection match the permanent upload-key SHA256
`39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43`.
Bundletool validation, package/version/min/target SDK, non-debuggable flags,
renderer metadata, all three ABI sets and ZIP-local/ELF alignment pass.
All **87 dependency metadata entries** and **9 non-application native
libraries** remain byte-identical to code5. [downloaded APK/AAB and independent tools, 2026-09-09]

`jarsigner` reports `jar verified.` but retains self-signed/untrusted-chain,
no-timestamp, POSIX metadata and manifest-order warnings. These are not
presented as a warning-free signature check. APK v2 validation and pinned
certificate match are independently established. [candidate verification artifact, 2026-09-09]

[CI34340981407](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34340981407)
installed code6 over code5 on a disposable **Android15/API35 x86_64** emulator,
without uninstalling or clearing storage. The byte-identical original
native regression passed **three cold starts**; each remained alive and
foreground and displayed the real title UI. Synthetic prior progress
remained exactly unchanged: **2 stars, 1 cleared course, 4-day streak,
Daily best42%/9 attempts**, along with other seeded values. The fixture
includes damaged optional replay data and `supporter=false`; it does not
simulate a purchase. [downloaded run summary, native UI/logs and exact preference comparison, 2026-09-09]

App-only logs show WorkManager continuing into Flutter, not the former
fatal provider/Room exception. The broad third-launch exception matches
belong to Android Settings PID3994, not Fliptide PID3959. Emulator GPU/frame
timing and the existing Impeller opt-out deprecation warning are retained;
no physical-phone performance claim is inferred. [primary logcat and process/activity evidence, 2026-09-09]

Two new harness-infrastructure failures are recorded rather than hidden:

- First update-fixture run34340692057: `Cannot identify fixture owner UID`.
  Android15 exposes `appId=`; one parser-only correction to accept it on
  User0 led to the successful run above. This failed before code6 launch.
- First fresh gameplay run34342026072: three fresh cold starts/title pass,
  then `element indices must be integers` before the first tap. ElementTree
  bounds access corrected from indexing to its attribute API; one gameplay
  retry34342365734 was blocked before gameplay by
  `UI condition not reached: fresh-title; labels=["Pixel Launcher isn't responding", 'Close app', 'Wait']`.
  Primary activity evidence attributes the focused ANR dialog to
  `com.google.android.apps.nexuslauncher`, not Fliptide. The app remained
  alive, but the dialog hid its screen. This is NOT a gameplay/UI pass.
  No runtime expectation or app binary changed. The single retry is
  exhausted; no dialog suppression, third run or weakened check.

The original native checker SHA256 remains
`fce1159445f92775ccabee3fd699b17552b410ca1cd5e9c9c94379c3feffc9dd`;
the DEX checker remains
`0f3e8051485ac0b86223c28ba03387259ac283aadeca54ad9507cd67981cedd2`.

## Publication status

**VERIFIED:** the exact code6 AAB is **Available to internal testers** on
internal track `4700947914971037408`, release6, full rollout. The same
library bundle is submitted to closed Alpha `4699887822350597006`, release5,
**In review**, full rollout across the existing177 countries/regions.
Code5 remains available to closed testers until review clears. Internal and
closed previews show **zero device-support losses or gains** across every
listed form factor; production is unchanged. [independently reread Play release-overview and track rows, 2026-09-09]

Browser-side AAB SHA256 was recomputed before upload and matched the
downloaded checked artifact. Play's bundle explorer reports all three ABIs,
min24/target36 and **Supports16KB**; full R8 and optimized resource shrinking
remain on. No promotion to production, tester-list expansion or account
security/signing changes. [authenticated upload, preview and bundle details, 2026-09-09]

ASSUMED risk decision: promote this narrow, startup-verified candidate to
the two existing testing tracks rather than retain a reproducibly broken
code5. The optional extended gameplay/resume scope is blocked and stays
false; it is not removed or called green. Production and the actual-phone
gate remain untouched. The owner was informed of this boundary before
publication. This is not whole-project completion.

## VERIFIED package returned by Google Play

Downloaded the **Signed, universal APK** from code6's authenticated bundle
explorer, artifact `4860228455413216187`; not a sideload recommendation.
Size **55,792,908 bytes**, SHA256
`f7cc9feb208aadd0e4975330b97e18719423a79b0860632a0e54b9ced5345fb1`.
The same DEX constructor assertion passes. All **22 DEX/native-library/
Flutter-asset payload files** are byte-identical to the checked CI APK.
Actual manifest still identifies package `com.tsorostudios.fliptide`,
0.3.2/code6, min24/target36 and Impeller=false. [downloaded Play APK and read-only payload/manifest inspection, 2026-09-09]

Official apksigner verifies **v2, v3 and Google SourceStamp**. The app-signing
certificate SHA256
`2aa37bb9ce6cb433a095d51debc6ba71d17d6a15a088e10315af86539636f7ed`
matches the fingerprint in Console's Digital Asset Links snippet. It is
correctly distinct from the upload-key pin; Console independently confirms
the unchanged upload pin. Two unknown additional v3 attribute warnings
(`0xbf940529`, `0x9f06b79c`) are retained, not hidden.
[official signature output and authenticated App signing readback, 2026-09-09]

This inspection does **not** execute Google's ARM split packages or the
owner's phone. Catalog search for S26 returned13 entries across two pages
but no itel S26 marketing name; the exact owner model/SKU/Android version
remains unknown. Do not substitute a Samsung S26 row or infer that the
owner's device lost support. [actual catalog result pages and current owner report, 2026-09-09]

## Acceptance boundary

The reproduced emulator defect is real. It is not a captured stack from the
owner's phone. Keep `F-ANDROID-LAUNCH-DEVICE-20260909`, F3 and F7 false until
their existing acceptance evidence exists. The owner should update through
Play without uninstalling and report installed version, launch, retained
progress, play/retry and background/resume.
