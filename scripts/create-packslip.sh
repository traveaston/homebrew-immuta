#!/usr/bin/env bash
# Describe and sign a packslip for an Immuta CLI release that fetch-release.sh
# has already downloaded and verified into <dir>.
#
# Usage: create-packslip.sh <version> <dir> <out> [packslip create flags...]
#
# Extra flags pass through to `packslip create`: CI signs keylessly with no
# extras, and a dry run passes `--key <file> --no-log`. Needs `packslip` on PATH
# and GITHUB_REPOSITORY (owner/repo), which GitHub Actions sets.
#
# The packslip is a repackager's: Immuta built and hosts the binaries, so the
# URLs are Immuta's own and the evidence lists the checks fetch-release.sh ran.
# Only pass a <dir> that fetch-release.sh --require-signatures produced, or the
# vendor-signature evidence is untrue.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[[ $# -ge 3 ]] || die "usage: $(basename "$0") <version> <dir> <out> [packslip create flags...]"
version="${1#v}"
dir="$2"
out="$3"
shift 3
repo="${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/repo}"
server="${GITHUB_SERVER_URL:-https://github.com}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

shopt -s nullglob
artifacts=("$dir"/immuta_cli_*)
[[ ${#artifacts[@]} -gt 0 ]] || die "no immuta_cli_* artifacts in $dir"

packslip create \
  --project "github.com/$repo" \
  --version "$version" \
  --tag "v$version" \
  --source-repo "$server/$repo" \
  --commit "$(git -C "$root" rev-parse HEAD)" \
  --url-base "https://immuta-platform-artifacts.s3.amazonaws.com/cli/v$version" \
  --notes-url "https://documentation.immuta.com/latest/releases/releases/immuta-cli-release-notes#immuta-cli-v$version" \
  --bin immuta \
  --resource 'completion/bash,zsh,fish,powershell=exec:immuta completion {shell}' \
  --attested-by repackager \
  --evidence checksum-file-over-tls \
  --evidence 'vendor-signature=Apple Developer ID Application: Immuta, Inc. (VSQ84595BS), darwin artifacts only' \
  --out "$out" \
  "$@" \
  -- "${artifacts[@]}"
