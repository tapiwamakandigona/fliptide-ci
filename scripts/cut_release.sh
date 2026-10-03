#!/usr/bin/env bash
# Owner-triggered ("cut") GitHub Release on the public mirror. Never run without the owner's word.
# Usage: GH_TOKEN=... scripts/cut_release.sh vX.Y.Z [run_id]
#   - downloads APK/AAB/web zip from the given (default: latest successful) CI run on fliptide-ci
#   - verifies APK signer cert against the pinned SHA-256 (same pin as ci.yml)
#   - writes SHA256SUMS, creates tag + release with assets, then re-downloads one asset
#     WITHOUT auth and re-checks its hash (release definition: tag + assets + sha256 + unauthenticated re-download).
set -euo pipefail
TAG="${1:?tag like v0.1.0}"; MIRROR=tapiwamakandigona/fliptide-ci
PIN=39cdb292e19291fa044c8bd39396369dfa7cc43cbef07ee7fd3f15880b833a43
RUN="${2:-$(gh run list -R $MIRROR --status success --limit 1 --json databaseId --jq '.[0].databaseId')}"
WORK=$(mktemp -d /work/temp/cut.XXXX); cd "$WORK"
echo "run=$RUN tag=$TAG work=$WORK"
gh run download "$RUN" -R $MIRROR -n fliptide-release-apk -n fliptide-release-aab -n fliptide-web
mv fliptide-release-apk/app-release.apk "fliptide-$TAG.apk"
mv fliptide-release-aab/app-release.aab "fliptide-$TAG.aab"
mv fliptide-web/fliptide-web.zip "fliptide-$TAG-web.zip"
APKSIGNER=$(ls "${ANDROID_SDK_ROOT:-/work/temp/android-sdk}"/build-tools/*/apksigner | tail -1)
GOT=$($APKSIGNER verify --print-certs "fliptide-$TAG.apk" | grep -oP 'SHA-256 digest: \K[0-9a-f]+' | head -1)
[ "$GOT" = "$PIN" ] || { echo "SIGNER PIN MISMATCH: $GOT"; exit 1; }
sha256sum fliptide-$TAG.* > SHA256SUMS; cat SHA256SUMS
SHA=$(gh api repos/$MIRROR/commits/main --jq .sha)
gh release create "$TAG" -R $MIRROR --target "$SHA" --title "Fliptide $TAG" \
  --notes "$(printf 'Fliptide %s\n\nAssets: signed APK (sideload), AAB (Play upload), web build zip.\nCI run: https://github.com/%s/actions/runs/%s\n\n%s' "$TAG" $MIRROR "$RUN" "$(sed 's/^/    /' SHA256SUMS)")" \
  fliptide-$TAG.apk fliptide-$TAG.aab fliptide-$TAG-web.zip SHA256SUMS
# Unauthenticated re-download check
URL="https://github.com/$MIRROR/releases/download/$TAG/fliptide-$TAG.apk"
sleep 5; curl -sSL -o recheck.apk "$URL"
grep "fliptide-$TAG.apk" SHA256SUMS | sed 's#fliptide#recheck#; s#recheck-.*#recheck.apk#' > recheck.sum
sha256sum -c recheck.sum && echo "RELEASE OK: https://github.com/$MIRROR/releases/tag/$TAG"
