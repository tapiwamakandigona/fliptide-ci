# Fliptide

One-tap gravity-flip runner. Same course for everyone today. Tsoro Studios.
Private source of truth — public releases, CI and the web build live at
https://github.com/tapiwamakandigona/fliptide-ci
(play: https://tapiwamakandigona.github.io/fliptide-ci/).

- Resume point: `PROJECT.md` · definition of done: `features.json`
- Standards: `DEMAND.md` (owner/lead edit this to redirect the work)
- Log: `progress.md` · plan: `docs/gauntlet-plan.md`

```
flutter test                                                  # sim + solver + content + share tests
flutter build web --release --wasm --base-href /fliptide-ci/  # web build (served from fliptide-ci Pages)
flutter build apk --release                                   # signed with android/signing/upload.keystore
dart run tool/try_chunk.dart 'row1|row2|row3|row4|row5|row6'  # solve a chunk grid
python tool/webtest/shots.py [url]                            # look-loop screenshots (see file header)
```
