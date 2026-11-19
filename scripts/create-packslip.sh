#!/usr/bin/env bash
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[[ $# -ge 2 ]] || die "usage: $(basename "$0") <version> <out> [packslip create flags...]"
version="${1#v}"
out="$2"
shift 2
repo="${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/repo}"
server="${GITHUB_SERVER_URL:-https://github.com}"
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
"$scripts/fetch-release.sh" --require-signatures "$version" "$dir"
artifacts=("$dir"/immuta_cli_*)

packslip create \
  --project "github.com/$repo" \
  --version "$version" \
  --tag "v$version" \
  --source-repo "$server/$repo" \
  --commit "$(git -C "$scripts" rev-parse HEAD)" \
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
