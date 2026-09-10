# VERIFIED 0.3.1 (5) compatibility package — 2026-09-09

Private built source `769b519`; public mirror
`559b1d51fc3952713fb2efdce65815eefbd9f9bb`. This is a version-only packaging
step after the renderer-configuration candidate, not another gameplay fix.
All previous tests and the CI workflow are unchanged.

[Manual CI34313820744](https://github.com/tapiwamakandigona/fliptide-ci/actions/runs/34313820744)
succeeded: analyzer clean, **176 passed / three pre-existing optional skips**,
signed APK and AAB; Pages skipped. The GitHub App dispatch was denied before
execution; the explicitly owner-authorized PAT retry succeeded after exact
identity/public-repo/ref/workflow verification. No paid private CI enabled.

## Independent downloaded-artifact verification

- Artifact ZIP SHA256 and byte counts match GitHub metadata; outer and inner
  ZIP CRCs pass.
- Android build-tools36 `apksigner verify --verbose --print-certs`: **Verifies**.
- JDK17 `jarsigner -verify -verbose -certs`: **jar verified**, no unsigned
  entries. Self-signed publisher-certificate warnings are expected; the
  actual certificate is separately pinned.
- Official bundletool1.17.2: **validate passes**, merged manifest inspected.
- Both APK and AAB: package `com.tsorostudios.fliptide`, version **0.3.1 /
  code5**, **minSdk24 / targetSdk36**, non-debuggable, existing AdMob
  application identifier, application-level **EnableImpeller=false**.
- APK v2/v3 and AAB PKCS7 certificates both match permanent upload pin
  `39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43`.

[primary Actions output and local downloaded-artifact verification, 2026-09-09]

| File | Bytes | SHA256 |
|---|---:|---|
| app-release.aab | 56993398 | `2cec9c9bbd8daef30719ded81f33edcb787db50c667dcc9dfea8c1bf2c49d8f8` |
| app-release.apk | 55705476 | `16464b50d482b0e25d8870e76bba6562369e0a67537185fd322bb3a50ba7fd48` |

Artifact ZIPs: AAB id10089518320,
`cf2a8eb48f2a001b07a21cc100716150afd4bab8be16ac6ad4462201a6223ae7`;
APK id10089517311,
`ad65d5c2f08afcbae99a7ecf008256d24090356c7ecbb1835326ce75c9f9f984`.
ZIP digests are not the inner binary hashes above.

## What this does not prove

No Google Play upload, installed Play split inspection, affected-phone
launch, actual purchase/restore or crash resolution. Internal publication
needs its separate scope approval. Do not ask the owner to uninstall a
Play-signed install to sideload an upload-key APK; preserve saved progress
and validate through the correct Play update path.

Configuration/package criteria pass. The affected-device feature and original
F3/F7 remain false. No closed-Alpha/production promotion or tester announcement
is part of package validation.
