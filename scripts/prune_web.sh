#!/usr/bin/env bash
# Post-build prune for the web bundle (directive 2026-09-02i, item 1).
#
# `flutter build web --wasm` ships EVERY renderer variant so the loader can pick
# one at runtime. With our bootstrap config (web/flutter_bootstrap.js:
# canvasKitBaseUrl "canvaskit/", canvasKitVariant "full", no wimp, no
# experimental paragraph) the loader can only ever request:
#
#   Chromium with WasmGC (Chrome/Edge/Android 119+) .. main.dart.wasm + main.dart.mjs
#                                                     + canvaskit/skwasm.{js,wasm}
#   Chromium without WasmGC (old Chromebooks) ........ main.dart.js + canvaskit/canvaskit.{js,wasm}
#   Firefox, Safari (dart2wasm allowlist = blink only)  main.dart.js + canvaskit/canvaskit.{js,wasm}
#
# Everything below is therefore unreachable and is deleted. Each deletion is
# printed with its size so the trim is auditable. Decoded from flutter.js:
#   canvaskit/chromium/*        – picked only when canvasKitVariant != "full";
#                                 we pin "full" so old Chromium loads the same
#                                 full canvaskit.wasm every other browser uses
#                                 (+1.5 MB for that slice, -5.8 MB in the package)
#   canvaskit/skwasm_heavy.*    – picked only on a Chromium engine that lacks
#                                 ImageDecoder or Intl.v8BreakIterator; both exist
#                                 in every Chromium that has WasmGC (>= 119)
#   canvaskit/wimp.*            – picked only when config.enableWimp is set (it is not)
#   canvaskit/experimental_webparagraph/* – picked only when
#                                 canvasKitVariant == "experimentalWebParagraph"
#   canvaskit/*.symbols         – debug symbol maps, never fetched
#   flutter_service_worker.js   – only when a caller opts in (we do not; CrazyGames
#                                 and Pages serve fresh files themselves)
#
# Usage: scripts/prune_web.sh <build/web dir>
set -euo pipefail
DIR="${1:?usage: prune_web.sh <web build dir>}"
[ -f "$DIR/flutter_bootstrap.js" ] || { echo "not a flutter web build: $DIR" >&2; exit 1; }
grep -q 'canvasKitVariant: *"full"' "$DIR/flutter_bootstrap.js" \
  || { echo "ERROR: bootstrap does not pin canvasKitVariant \"full\"; pruning canvaskit/chromium would break old Chromium." >&2; exit 1; }

before=$(du -sb "$DIR" | cut -f1)
echo "before: $before bytes ($(du -sh "$DIR" | cut -f1))"

prune() {
  local p="$DIR/$1"
  if [ -e "$p" ]; then
    local sz; sz=$(du -sb "$p" | cut -f1)
    printf 'delete %10d  %s\n' "$sz" "$1"
    rm -rf "$p"
  fi
}
prune canvaskit/chromium
prune canvaskit/experimental_webparagraph
prune canvaskit/skwasm_heavy.js
prune canvaskit/skwasm_heavy.wasm
prune canvaskit/wimp.js
prune canvaskit/wimp.wasm
prune flutter_service_worker.js
find "$DIR/canvaskit" -name '*.symbols' -print -delete | sed 's/^/delete            /'

after=$(du -sb "$DIR" | cut -f1)
echo "after:  $after bytes ($(du -sh "$DIR" | cut -f1)); removed $(( (before-after)/1024/1024 )) MB"
echo "kept:"; (cd "$DIR" && find . -type f -printf '%s\t%p\n' | sort -rn | head -12)
