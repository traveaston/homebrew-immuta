#!/usr/bin/env bash
# Report the newest published Immuta CLI release against the version this tap
# pins. Read-only: it never edits the formula.
set -euo pipefail

RELEASE_NOTES="https://documentation.immuta.com/latest/releases/releases/immuta-cli-release-notes"
FORMULA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Formula/immuta.rb"

pinned="$(sed -n 's/^  version "\(.*\)"$/\1/p' "$FORMULA")"
if [[ -z $pinned ]]; then
  echo "error: no version found in $FORMULA" >&2
  exit 1
fi

# The artifact bucket denies ListBucket, so releases can only be discovered from
# the release notes, where each one is an `immuta-cli-v<version>` heading anchor.
latest="$(
  curl -fsSL --max-time 30 "$RELEASE_NOTES" |
    grep -oE 'id="immuta-cli-v[0-9]+(\.[0-9]+)+"' |
    sed -E 's/^id="immuta-cli-v([0-9.]+)"$/\1/' |
    sort -t. -k1,1n -k2,2n -k3,3n |
    tail -1
)"
if [[ -z $latest ]]; then
  echo "error: no releases found at $RELEASE_NOTES" >&2
  echo "       the page layout may have changed; check the anchor format" >&2
  exit 1
fi

echo "pinned:    $pinned"
echo "published: $latest"

if [[ $pinned == "$latest" ]]; then
  echo "up to date"
else
  echo
  echo "to upgrade, review the release notes then run:"
  echo "  scripts/update-formula.sh $latest"
fi
