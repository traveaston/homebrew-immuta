#!/usr/bin/env bash
# Pin Formula/immuta.rb to a specific Immuta CLI release.
#
# Every artifact is downloaded and checked against the vendor's published
# SHA256SUMS, and the macOS binaries are checked against Immuta's Apple
# Developer ID signature, before anything is written. The script edits the
# formula and stops -- it never commits, tags, or pushes.
set -euo pipefail

BASE_URL="https://immuta-platform-artifacts.s3.amazonaws.com/cli"
TARGETS=(darwin_amd64 darwin_arm64 linux_amd64 linux_arm64)

# The SHA256SUMS file lives in the same bucket as the artifacts, so on its own it
# proves only that the download was not corrupted in transit. Immuta's Apple
# Developer ID signature is an independent root of trust, so verify it too where
# the tooling exists to do so.
APPLE_TEAM_AUTHORITY="Developer ID Application: Immuta, Inc. (VSQ84595BS)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA="$ROOT/Formula/immuta.rb"

die() { echo "error: $*" >&2; exit 1; }

version="${1:-}"
[[ -n $version ]] || die "usage: $(basename "$0") <version>   (e.g. $(basename "$0") 1.4.0)"
version="${version#v}"
[[ $version =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "'$version' is not a version number"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "==> Downloading v$version"
curl -fsSL --max-time 60 -o "$work/SHA256SUMS" "$BASE_URL/v$version/immuta_cli_SHA256SUMS" ||
  die "no checksums at $BASE_URL/v$version/ -- is v$version a real release?"
for target in "${TARGETS[@]}"; do
  # Bail on a stalled transfer rather than a slow one: these are ~12 MB each and
  # the bucket is not always fast.
  curl -fsSL --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
    --retry 3 --retry-delay 2 -o "$work/immuta_cli_$target" \
    "$BASE_URL/v$version/immuta_cli_$target" || die "could not download immuta_cli_$target"
done

echo "==> Verifying checksums"
grep -v windows "$work/SHA256SUMS" > "$work/SHA256SUMS.unix"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$work" && sha256sum -c SHA256SUMS.unix) || die "checksum mismatch"
else
  (cd "$work" && shasum -a 256 -c SHA256SUMS.unix) || die "checksum mismatch"
fi

if command -v codesign >/dev/null 2>&1; then
  echo "==> Verifying macOS code signatures"
  for target in darwin_amd64 darwin_arm64; do
    codesign --verify --strict "$work/immuta_cli_$target" 2>/dev/null ||
      die "immuta_cli_$target has an invalid code signature"
    authority="$(codesign -dvvv "$work/immuta_cli_$target" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
    [[ $authority == "$APPLE_TEAM_AUTHORITY" ]] ||
      die "immuta_cli_$target is signed by '$authority', expected '$APPLE_TEAM_AUTHORITY'"
    echo "immuta_cli_$target: $authority"
  done
else
  echo "==> Skipping code signature check (codesign not available on this platform)"
fi

echo "==> Rewriting $(basename "$FORMULA")"
sums=""
for target in "${TARGETS[@]}"; do
  sum="$(awk -v t="immuta_cli_$target" '$2 == t { print $1 }' "$work/SHA256SUMS")"
  [[ -n $sum ]] || die "no checksum published for immuta_cli_$target"
  sums+="$target=$sum;"
done

cp "$FORMULA" "$work/before.rb"
awk -v ver="$version" -v sums="$sums" '
  BEGIN {
    n = split(sums, pairs, ";")
    for (i = 1; i <= n; i++)
      if (split(pairs[i], kv, "=") == 2) sha[kv[1]] = kv[2]
  }
  /^  version "/ { print "  version \"" ver "\""; next }
  /^ *url ".*immuta_cli_/ {
    target = $0
    sub(/.*immuta_cli_/, "", target)
    sub(/".*/, "", target)
    gsub(/\/cli\/v[0-9][0-9.]*\//, "/cli/v" ver "/")
    print
    next
  }
  /^ *sha256 "/ && target != "" && (target in sha) {
    match($0, /^ */)
    print substr($0, 1, RLENGTH) "sha256 \"" sha[target] "\""
    target = ""
    next
  }
  { print }
' "$work/before.rb" > "$work/after.rb"

grep -q "\"$version\"" "$work/after.rb" || die "rewrite produced no version change; check the formula layout"
cp "$work/after.rb" "$FORMULA"

echo
diff -u "$work/before.rb" "$FORMULA" --label "a/Formula/immuta.rb" --label "b/Formula/immuta.rb" || true
echo
echo "==> Formula updated to v$version. Nothing has been committed."
echo "    Review the diff, then: brew style Formula/immuta.rb && brew audit --formula immuta"
