#!/usr/bin/env bash
# Download one Immuta CLI release into a directory and verify it, so that every
# channel this repo publishes (the Homebrew formula, the packslip) pins bytes
# that went through the same checks.
#
# Usage: fetch-release.sh [--require-signatures] <version> <dir>
#
# Writes immuta_cli_<os>_<arch> for each target, plus SHA256SUMS, into <dir>.
# Every artifact is checked against the vendor's published SHA256SUMS. Where
# `codesign` exists, the macOS binaries are also checked against Immuta's Apple
# Developer ID signature; --require-signatures makes that check mandatory
# rather than skipped, for callers that go on to claim it was done.
set -euo pipefail

BASE_URL="https://immuta-platform-artifacts.s3.amazonaws.com/cli"
TARGETS=(darwin_amd64 darwin_arm64 linux_amd64 linux_arm64)

# The SHA256SUMS file lives in the same bucket as the artifacts, so on its own it
# proves only that the download was not corrupted in transit. Immuta's Apple
# Developer ID signature is an independent root of trust, so verify it too where
# the tooling exists to do so.
APPLE_TEAM_AUTHORITY="Developer ID Application: Immuta, Inc. (VSQ84595BS)"

die() { echo "error: $*" >&2; exit 1; }

require_signatures=false
if [[ ${1:-} == --require-signatures ]]; then
  require_signatures=true
  shift
fi

version="${1:-}"
dir="${2:-}"
[[ -n $version && -n $dir ]] ||
  die "usage: $(basename "$0") [--require-signatures] <version> <dir>"
version="${version#v}"
[[ $version =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "'$version' is not a version number"
mkdir -p "$dir"

echo "==> Downloading v$version"
curl -fsSL --max-time 60 -o "$dir/SHA256SUMS" "$BASE_URL/v$version/immuta_cli_SHA256SUMS" ||
  die "no checksums at $BASE_URL/v$version/ -- is v$version a real release?"
for target in "${TARGETS[@]}"; do
  # Bail on a stalled transfer rather than a slow one: these are ~12 MB each and
  # the bucket is not always fast.
  curl -fsSL --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
    --retry 3 --retry-delay 2 -o "$dir/immuta_cli_$target" \
    "$BASE_URL/v$version/immuta_cli_$target" || die "could not download immuta_cli_$target"
done

echo "==> Verifying checksums"
for target in "${TARGETS[@]}"; do
  awk -v t="immuta_cli_$target" '$2 == t' "$dir/SHA256SUMS"
done > "$dir/SHA256SUMS.targets"
[[ $(wc -l < "$dir/SHA256SUMS.targets") -eq ${#TARGETS[@]} ]] ||
  die "SHA256SUMS does not list every target"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$dir" && sha256sum -c SHA256SUMS.targets) || die "checksum mismatch"
else
  (cd "$dir" && shasum -a 256 -c SHA256SUMS.targets) || die "checksum mismatch"
fi
rm "$dir/SHA256SUMS.targets"

if command -v codesign >/dev/null 2>&1; then
  echo "==> Verifying macOS code signatures"
  for target in darwin_amd64 darwin_arm64; do
    codesign --verify --strict "$dir/immuta_cli_$target" 2>/dev/null ||
      die "immuta_cli_$target has an invalid code signature"
    authority="$(codesign -dvvv "$dir/immuta_cli_$target" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
    [[ $authority == "$APPLE_TEAM_AUTHORITY" ]] ||
      die "immuta_cli_$target is signed by '$authority', expected '$APPLE_TEAM_AUTHORITY'"
    echo "immuta_cli_$target: $authority"
  done
elif $require_signatures; then
  die "codesign is not available, and --require-signatures was given"
else
  echo "==> Skipping code signature check (codesign not available on this platform)"
fi

chmod 0755 "$dir"/immuta_cli_*
