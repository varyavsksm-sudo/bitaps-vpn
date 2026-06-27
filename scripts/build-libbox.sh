#!/bin/zsh
# Builds Libbox.xcframework (the sing-box engine the PacketTunnel runs) from
# source via sing-box's own gomobile fork. Needs: full Xcode, ~2GB disk, network.
# Output: ./Libbox.xcframework  (add it to the PacketTunnel target, do NOT commit).
set -e
WORK=${1:-/tmp/libbox-build}
mkdir -p "$WORK" && cd "$WORK"

# 1. Go toolchain (gomobile needs >=1.25; sing-box build_libbox switches as needed)
if ! command -v go >/dev/null; then
  curl -fsSL -o go.tar.gz "https://go.dev/dl/go1.23.4.darwin-arm64.tar.gz"
  rm -rf goroot && mkdir goroot && tar -C goroot --strip-components=1 -xzf go.tar.gz
  export GOROOT="$WORK/goroot"; export PATH="$GOROOT/bin:$PATH"
fi
export GOPATH="$WORK/gopath" GOBIN="$WORK/gopath/bin"; export PATH="$GOBIN:$PATH"

# 2. sing-box source + its gomobile fork
[ -d sing-box ] || git clone --depth 1 https://github.com/sagernet/sing-box
cd sing-box
go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.13
go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.13
gomobile init

# 3. Build. `-target apple` = ios+ios-sim+macos+tvos; trim with -target ios,macos if wanted.
go run ./cmd/internal/build_libbox -target apple
echo "DONE → $WORK/sing-box/Libbox.xcframework"

# ─────────────────────────────────────────────────────────────────────────────
# LINKING THE RESULT INTO THE PacketTunnel TARGET (Xcode):
#  1. Drag Libbox.xcframework onto the PacketTunnel target → "Embed & Sign".
#  2. Libbox is a STATIC framework (alpha sing-box w/ tailscale/usbip) — add these
#     to PacketTunnel → Build Phases → Link Binary With Libraries:
#       Security, Network, SystemConfiguration, CoreText, IOKit, CoreServices,
#       AppKit, CoreLocation, NetworkExtension, UniformTypeIdentifiers,
#       IOUSBHost, Carbon, libresolv.tbd, libbsm.tbd
#     (verified by compiling/linking a harness against the macos slice).
#  3. Once linked, `#if canImport(Libbox)` becomes true and the real engine runs.
#
# CONFIG FORMAT NOTE: SingBoxConfig.swift targets sing-box 1.12+/1.14 (typed DNS
# servers, hijack-dns / reject rule-actions, remote rule_sets) — verified VALID
# for vless/reality, trojan, ss, hysteria2 via LibboxCheckConfig.
