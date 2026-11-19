#!/usr/bin/env bash
# Pin Formula/immuta.rb to a specific Immuta CLI release.
#
# The release is downloaded and verified by fetch-release.sh before anything is
# written. The script edits the formula and stops -- it never commits, tags, or
# pushes.
set -euo pipefail

TARGETS=(darwin_amd64 darwin_arm64 linux_amd64 linux_arm64)

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPTS")"
FORMULA="$ROOT/Formula/immuta.rb"

die() { echo "error: $*" >&2; exit 1; }

version="${1:-}"
[[ -n $version ]] || die "usage: $(basename "$0") <version>   (e.g. $(basename "$0") 1.4.0)"
version="${version#v}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$SCRIPTS/fetch-release.sh" "$version" "$work"

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
