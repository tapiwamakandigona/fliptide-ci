# VERIFIED internal release 0.3.1 (5) — 2026-09-09

The owner's September 9 request authorized Play updates. This action was
limited to the existing renderer-compatibility candidate on **internal
testing**, without expanding testers or changing closed Alpha/production.

## Independent source and artifact recheck

- Existing Actions34313820744 at public
  `559b1d51fc3952713fb2efdce65815eefbd9f9bb` remains successful. Original
  analyzer clean, **176 tests passed / three existing skips**; signed Android
  job successful; Pages skipped. No rebuild or application change by this task.
- Downloaded both nonexpired artifact ZIPs. GitHub digests and sizes match;
  outer ZIP and inner APK/AAB CRCs pass. Binary SHA256:
  - AAB: `2cec9c9bbd8daef30719ded81f33edcb787db50c667dcc9dfea8c1bf2c49d8f8`
  - APK: `16464b50d482b0e25d8870e76bba6562369e0a67537185fd322bb3a50ba7fd48`
- Official bundletool1.17.2 `validate` succeeds. AAB merged manifest confirms
  package `com.tsorostudios.fliptide`, **0.3.1/code5**, minSdk24/targetSdk36,
  nondebuggable and application-level EnableImpeller=false.
- JDK17 jarsigner says **jar verified**, no digest error. Certificate
  fingerprint matches immutable upload pin
  `39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43`.
  Self-signed certificate and JarInputStream/manifest-order warnings are
  recorded; not represented as a warning-free check. Bundletool and Play
  accepted the unchanged artifact.
- The browser-side AAB SHA256 was recomputed before assigning the file to the
  upload input; it matched the independent local/Actions-backed digest.

[primary Actions API/logs, downloaded artifacts and local read-only tools, 2026-09-09]

## Play preview and final readback

- Before: internal **4 (0.3.0)** and closed Alpha **4 (0.3.0)**.
- Preview: **Ready to release**, new bundle **5 (0.3.1)**. **Zero newly
  unsupported devices** across all seven displayed form factors.
- Existing internal track `4700947914971037408`, release5, no tester/listing/
  monetization change. Published the inspected release after the confirmation
  dialog; then re-navigated to the releases overview independently.
- Final: **5 (0.3.1) — Internal testing — Available to internal testers —
  Full roll-out**. Closed Alpha remains **4 (0.3.0)**, available to its existing
  testers. Google Play propagation/device receipt may lag Console.
- Release notes explicitly call this a compatibility test, request launch/
  existing-progress/play/retry/background-resume feedback and say **do not
  uninstall or clear app storage**.

[authenticated Play upload/preview/internal track and refreshed releases overview, 2026-09-09]

## Still unverified

No affected-phone launch, installed split inspection, actual purchase/restore,
low-end FPS or crash resolution. Original F3/F7 and the affected-device feature
remain false. Internal publication is not production or closed-Alpha promotion.
