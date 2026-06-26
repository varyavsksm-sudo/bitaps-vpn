#!/usr/bin/env bash
# Generates BitapsVPN.xcodeproj from project.yml using XcodeGen.
# Works without Homebrew — downloads a portable XcodeGen if it's missing.
set -euo pipefail
cd "$(dirname "$0")"

XG=""
if command -v xcodegen >/dev/null 2>&1; then
  XG="xcodegen"
else
  echo "XcodeGen not found — fetching a portable copy…"
  VER="2.43.0"
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${VER}/xcodegen.zip" -o "$TMP/xcodegen.zip"
  unzip -q "$TMP/xcodegen.zip" -d "$TMP"
  XG="$TMP/xcodegen/bin/xcodegen"
fi

echo "Generating project…"
"$XG" generate --spec project.yml
echo "✅ BitapsVPN.xcodeproj ready. Open with:  open BitapsVPN.xcodeproj"
