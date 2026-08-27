# homebrew-immuta

A Homebrew tap for the [Immuta CLI](https://documentation.immuta.com/latest/developer-guides/the-immuta-cli).

Immuta does not publish a Homebrew formula or tap. This one exists so the CLI can
be installed and upgraded through homebrew, instead of needing to manually manage
binary paths, permissions, etc.

**This tap is not affiliated with or endorsed by Immuta.**
It is maintained personally, on a best-effort basis.

## Install

```sh
brew tap traveaston/immuta
brew install immuta
```

Or just install using the fully-qualified name, automatically tapping.

```sh
brew install traveaston/immuta/immuta
```

Then check it works:

```sh
immuta --version
```

Bash, zsh, and fish completions are installed automatically.

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

## Credentials

`immuta configure` writes your tenant URL and API key **in plaintext** to
`~/.immutacfg.yaml`. Treat that file as a credential:

```sh
chmod 600 ~/.immutacfg.yaml
```

Use `--profile` to keep tenants separate, and `--config` to point at a different
file.
