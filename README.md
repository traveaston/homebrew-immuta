# homebrew-immuta

A Homebrew tap for the [Immuta CLI](https://documentation.immuta.com/latest/developer-guides/the-immuta-cli).

Immuta does not publish a Homebrew formula or tap. This one exists so the CLI can
be installed and upgraded through homebrew, instead of needing to manually manage
binary paths, permissions, etc.

**This tap is not affiliated with or endorsed by Immuta.**
It is maintained personally, on a best-effort basis.

## Install

```sh
brew install traveaston/immuta/immuta
```

Installing by fully-qualified name taps and trusts the formula in one step.

To install by short name instead, tap and trust it first:

```sh
brew tap traveaston/immuta
brew trust --formula traveaston/immuta/immuta
brew install immuta
```

The `brew trust` step is required as of
[Homebrew 6.0.0](https://docs.brew.sh/Tap-Trust): a formula is executable Ruby, not
plain metadata, so Homebrew no longer loads one from a third-party tap until you say
so. Trusting the formula rather than the whole tap (`brew trust traveaston/immuta`)
is deliberate — whole-tap trust also covers every formula added here in future,
sight unseen.

Then check it works:

```sh
immuta --version
```

Bash, zsh, and fish completions are installed automatically.

## Install with mise

Each pinned version is also published as a signed
[packslip](https://mise.jdx.dev/dev-tools/backends/packslip.html), so
[mise](https://mise.jdx.dev) can install it without Homebrew:

```sh
mise use -g packslip:traveaston/homebrew-immuta
```

mise downloads the binary from Immuta's bucket, checks it against the digest in
the packslip, and checks that this repo's release workflow signed that packslip.
With mise activated, shell completions load on demand.

## What it pins

The formula pins a single Immuta CLI version across four platforms:

| Platform | Artifact |
| --- | --- |
| macOS Intel | `immuta_cli_darwin_amd64` |
| macOS Apple Silicon | `immuta_cli_darwin_arm64` |
| Linux x86_64 | `immuta_cli_linux_amd64` |
| Linux arm64 | `immuta_cli_linux_arm64` |

Windows is published by Immuta but is out of scope for Homebrew.

Immuta serves the CLI from `immuta-platform-artifacts.s3.amazonaws.com` under two
prefixes: a mutable `cli/latest/` and an immutable `cli/v<version>/`.

## Bumping the pinned version (maintainers)

```sh
scripts/check-version.sh          # is there anything newer than what we pin?
scripts/update-formula.sh 1.5.0   # pin that version, after reading its release notes
```

`update-formula.sh` downloads all four artifacts, verifies each against Immuta's
published `immuta_cli_SHA256SUMS`, verifies the macOS binaries against Immuta's
Apple Developer ID signature, then rewrites the formula and prints the diff. It
stops there. Review the diff, run `brew style Formula/immuta.rb` and
`brew audit --formula immuta`, and commit.

Once the bump is merged, publish it for mise by pushing a matching tag:

```sh
git tag v1.5.0 && git push origin v1.5.0
```

The `packslip` workflow re-runs the same download and verification
(`scripts/fetch-release.sh`, on macOS so the code signatures are checked), signs
a packslip keylessly with the workflow's GitHub OIDC identity, and attaches it to
a GitHub release for the tag. It refuses a tag that does not match the formula's
version.

The artifact bucket denies `ListBucket`, so new versions cannot be discovered by
enumerating the prefix — `check-version.sh` reads the
[release notes](https://documentation.immuta.com/latest/releases/releases/immuta-cli-release-notes)
instead. For the same reason the formula carries no `livecheck` block; see the
comment in `Formula/immuta.rb`.

As of August 2026 the newest release is still v1.4.0, from July 2024.

## Supply-chain notes

- **Immutable URLs.** Every artifact is pinned to `cli/v<version>/`, never `latest`.
- **Checksums.** Every artifact carries a SHA-256 that Homebrew enforces on download.
  The values come from Immuta's published `immuta_cli_SHA256SUMS`, and
  `update-formula.sh` re-verifies them against the actual bytes rather than
  copying them in unread.
- **Signatures.** `SHA256SUMS` lives in the same bucket as the artifacts, so on its
  own it proves only that a download was not corrupted in transit. The macOS
  binaries are also signed `Developer ID Application: Immuta, Inc. (VSQ84595BS)`
  with a hardened runtime, which is an independent root of trust;
  `update-formula.sh` checks it on every bump. Immuta publishes no signatures for
  the Linux binaries, so those rest on the checksums alone.
- **The packslip is a repackager's.** It is signed by this repo, not by Immuta,
  and says so (`attested_by: repackager`), listing the checks above as its
  evidence. It is no stronger than those checks. What it adds is that mise pins
  the signing workflow, so a later release signed by anything else is refused.

## Credentials

`immuta configure` writes your tenant URL and API key **in plaintext** to
`~/.immutacfg.yaml`. Treat that file as a credential:

```sh
chmod 600 ~/.immutacfg.yaml
```

Use `--profile` to keep tenants separate, and `--config` to point at a different
file.
