#!/bin/sh
# Runs the PowerConfig checks with the Luau CLI (https://github.com/luau-lang/luau/releases).
# Luau sandboxes required modules, so the config is pasted into one file
# together with a stand-in for Roblox's Color3.
set -e
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
BUNDLE="$(mktemp "${TMPDIR:-/tmp}/powerconfig-test.XXXXXX")"
trap 'rm -f "$BUNDLE"' EXIT
{
	echo 'Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }'
	echo 'local PowerConfig = (function()'
	cat src/shared/PowerConfig.lua
	echo 'end)()'
	cat tests/PowerConfig.test.luau
} > "$BUNDLE"
"$LUAU" "$BUNDLE"
