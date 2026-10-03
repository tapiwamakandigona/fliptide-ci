# Android launch compatibility investigation

## Report and priority

**VERIFIED report:** the owner says Google Play version **0.3.0** displays
`app stopped working` before its first screen on an itel S26 Ultra, and that
the previous version also failed. Other games reportedly work. This is a
device report, not a reproduced stack trace. Android version and exact device
code remain unknown. Preserve app data; do not advise uninstall/clear-storage
as a first response. [private owner messages, 2026-09-09]

Pause new Fliptide recruitment pushes, production promotion and monetization
expansion until launch behavior is validated.

## Primary evidence gathered

- Play Android vitals: **No results**, including after removing the
  user-perceived-only filter; displayed data last updated Monday 00:00.
  Pre-launch overview asks to upload artifacts and has no report available.
  Missing/lagging reports do not refute the owner. [Play Console Crashes and ANRs / Pre-launch report DOM, 2026-09-09]
- Play submission activity **4 = Published** and closed Alpha **0.3.0 (4) =
  Available to selected testers**. Approval is not device compatibility. [Play submission activity and Alpha track, 2026-09-09]
- Previously verified GitHub v0.3.0 universal APK has package
  `com.tsorostudios.fliptide`, version **0.3.0 / 4**, minSdk **24**, targetSdk
  **36**, a present launcher class in DEX, and the configured AdMob application
  ID. ARM64, ARMv7 and x86_64 native libraries exist; all inspected ELF load
  segments support 16-KiB alignment. This is not inspection of the phone's
  Play-generated splits or evidence of successful execution. [APK manifest/DEX/ELF inspection, 2026-09-09]
- Both Emberdelve and Pyregrove shipping-candidate Android manifests explicitly
  set `io.flutter.embedding.android.EnableImpeller=false`. Fliptide source and
  the inspected APK do not override it. [primary repository manifests and APK metadata, 2026-09-09]
- Flutter documents the same application-level opt-out for Android release
  builds: [Impeller documentation](https://docs.flutter.dev/perf/impeller).
  A current SDK upgrade is not part of this mitigation.

## ASSUMED hypothesis, not confirmed cause

A renderer/driver incompatibility is a concrete candidate because it can fail
before Dart UI appears, and the other two games select the conservative
renderer. This does not identify the phone's actual GPU or prove an Impeller
crash. Third-party reports on other devices are context, not this crash trace.
Native plugins, Play splits, device state and other startup failures remain
possible until a device trace or controlled comparison discriminates them.

## Bounded plan

One compatibility task; at most **two test-only CI executions**:

1. Add one read-only manifest regression test. Run the existing public mirror
   PR workflow against unchanged app source and record the expected failure.
   This is a configuration regression, **not a reproduction of the device
   crash**.
2. Add only the documented Android application metadata opt-out. Keep the new
   test byte-identical, and every previous test/check unchanged. Run full
   analyzer/tests on the mirror; Android and Pages must stay skipped.
3. Verify exact private/public source bytes, unchanged package/signing/minSdk/
   dependencies/Flutter version and no credential material in the public diff.
   Commit a reviewable candidate, never claim it fixes the phone yet.

No gameplay changes, live ads, save reset, private workflow activation, SDK
upgrade, Pages deployment, store upload or production release is included.

## Acceptance after code checks

**VERIFIED code checks:** expected-red [run 34312151316](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34312151316)
had a clean analyzer, **175 passed / one new manifest failure / three existing
skips**. After only the manifest metadata change, [run 34312326052](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34312326052)
at public `1988359` had a clean analyzer and **176 passed / three existing
skips**. The new regression file remained byte-identical. Android and Pages
jobs skipped in both. The two test-only run cap is exhausted. [primary Actions jobs and logs, 2026-09-09]

The renderer candidate can pass code/configuration checks without closing
the incident. Next: same-key higher-version internal build, inspected merged
manifest/certificate, then a Play update on the affected phone without data
loss. Confirm repeated cold launches, opening an existing save, play/retry,
background/resume and the absence of a new startup crash trace.
If it still fails, capture the app-specific Android crash trace rather than
applying speculative patches. Keep original F3/F7 and this device gate false
until their actual acceptance evidence exists.
