#!/usr/bin/env bash
# Sync the private fliptide repo to the PUBLIC CI mirror (fliptide-ci).
#
# Why: GitHub Actions is billing-blocked on this account's private repos;
# public repos run Actions for free. The mirror carries NO signing material:
# android/signing/ and android/key.properties are stripped from every
# snapshot, and the mirror's history is snapshot-only (orphan commits), so
# the private repo's key-bearing history can never leak through it.
# CI on the mirror restores signing from Actions secrets
# (UPLOAD_KEYSTORE_B64 / KEY_PROPERTIES_B64) — see ci.yml.
#
# Usage: scripts/sync_public_ci.sh [tag]
#   Run from the repo root on the commit you want mirrored (usually a
#   release tag). If [tag] is given, the mirror commit is also tagged.
set -euo pipefail

MIRROR_URL="https://github.com/tapiwamakandigona/fliptide-ci.git"
SRC_SHA="$(git rev-parse HEAD)"
SRC_DESC="$(git log -1 --format='%h %s' | head -c 100)"
TAG="${1:-}"
# Mirror branch to (force-)push the snapshot to. Default main. Work branches
# (e.g. MIRROR_BRANCH=next/android-ads) get their own snapshot so CI can build
# them by workflow_dispatch without touching the live Pages site (ci.yml gates
# the Pages job to main).
MIRROR_BRANCH="${MIRROR_BRANCH:-main}"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree not clean; commit or stash first." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Export exactly the committed tree (no untracked files), then strip keys.
git archive HEAD | tar -x -C "$TMP"
rm -rf "$TMP/android/signing"
rm -f "$TMP/android/key.properties"
# Belt & braces: fail loudly if any keystore-looking file survived.
if find "$TMP" -name '*.keystore' -o -name '*.jks' -o -name 'key.properties' | grep -q .; then
  echo "ERROR: signing material found in mirror tree — aborting." >&2
  exit 1
fi

cat > "$TMP/MIRROR.md" <<EOF
# Public CI mirror

Snapshot mirror of the private \`tapiwamakandigona/fliptide\` repo, kept
only so GitHub Actions can run for free. **No signing keys live here** —
CI restores them from Actions secrets. Do not develop against this repo;
source of truth is the private repo.

Synced from private commit: $SRC_SHA
EOF

cd "$TMP"
git init -q -b "$MIRROR_BRANCH"
git add -A
git -c user.name="Tapiwa Makandigona" -c user.email="tapiwamakandigoner@gmail.com" \
  commit -q -m "sync: private @${SRC_DESC}" -m "source-sha: ${SRC_SHA}"
if [ -n "$TAG" ]; then
  git tag "$TAG"
fi
git push --force "$MIRROR_URL" "$MIRROR_BRANCH" ${TAG:+refs/tags/$TAG}
echo "Mirror synced to $MIRROR_URL @ $MIRROR_BRANCH (source $SRC_SHA)${TAG:+, tag $TAG}"
