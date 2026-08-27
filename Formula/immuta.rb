class Immuta < Formula
  desc "CLI for Immuta data sources, projects, purposes, and policies"
  homepage "https://documentation.immuta.com/latest/developer-guides/the-immuta-cli"
  version "1.4.0"
  # Immuta publishes the CLI as a proprietary binary with no accompanying
  # license file or SPDX identifier.
  license :cannot_represent

  # There is deliberately no `livecheck` block. Homebrew requires `livecheck` to
  # precede the `on_*` blocks, and its `LivecheckUrlSymbol` cop resolves the
  # stable URL by taking the first `url` in the class body -- which, for a
  # formula whose every URL is inside an `on_*` block, is the livecheck URL
  # itself. `brew audit` then fails on a false positive that cannot be silenced
  # inline. `scripts/check-version.sh` reports new releases instead.

  # Immuta publishes one bare binary per OS/arch under an immutable
  # `cli/v<version>/` prefix, alongside `immuta_cli_SHA256SUMS`. The mutable
  # `cli/latest/` prefix is deliberately not used here: a formula must resolve
  # to the same bytes on every machine, forever.
  #
  # Checksums are the vendor's published values, independently re-verified
  # against the downloaded artifacts by `scripts/update-formula.sh`.
  on_macos do
    on_intel do
      url "https://immuta-platform-artifacts.s3.amazonaws.com/cli/v1.4.0/immuta_cli_darwin_amd64"
      sha256 "a42892550e1286653d84ad5f54f925a00cc5b2a6cbd081dd7b104d2989430f92"
    end
    on_arm do
      url "https://immuta-platform-artifacts.s3.amazonaws.com/cli/v1.4.0/immuta_cli_darwin_arm64"
      sha256 "422cc793dd35c522c08638f71a0ad5a5231a9435af41fa81ff971b2898a3d018"
    end
  end

  on_linux do
    on_intel do
      url "https://immuta-platform-artifacts.s3.amazonaws.com/cli/v1.4.0/immuta_cli_linux_amd64"
      sha256 "e40281dc577f9e132715d0b777bb284b74b9c170c3c9f0bb76ac9426ef8b4269"
    end
    on_arm do
      url "https://immuta-platform-artifacts.s3.amazonaws.com/cli/v1.4.0/immuta_cli_linux_arm64"
      sha256 "3d2d0b411b1af72de30ea1d808536e78b353641bddbba658f80d0bc3c236d903"
    end
  end

  def install
    os = OS.mac? ? "darwin" : "linux"
    arch = Hardware::CPU.arm? ? "arm64" : "amd64"

    bin.install "immuta_cli_#{os}_#{arch}" => "immuta"
    chmod 0755, bin/"immuta"

    generate_completions_from_executable(bin/"immuta", "completion")
  end

  def caveats
    <<~EOS
      `immuta configure` writes your tenant URL and API key in plaintext to
      ~/.immutacfg.yaml. Treat that file as a credential:

        chmod 600 ~/.immutacfg.yaml

      This tap is not affiliated with or endorsed by Immuta.
    EOS
  end

  test do
    assert_match "Version: v#{version}", shell_output("#{bin}/immuta --version")
    assert_match "Available Commands:", shell_output("#{bin}/immuta --help")
    assert_match "bash completion for immuta", shell_output("#{bin}/immuta completion bash")
  end
end
