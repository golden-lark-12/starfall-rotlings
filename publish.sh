#!/usr/bin/env bash
# Starfall Rotlings — pre-publish gate + publish.
# Runs the auto-checks FIRST and stops before building or publishing
# on any failure. Never publish by calling the Open Cloud helper
# directly: always go through this script so the gate cannot be
# skipped.
#
# Usage (from the repo root):
#   ./publish.sh
#
# Steps:
#   1. lune run auto-checks.luau .        (fails the build on any FAIL)
#   2. rojo build default.project.json --output game.rbxl
#   3. publish-assets to the Private place (Universe 4450691933,
#      Place 12693934119) via the Open Cloud helper.
# The place stays Private until Malek says go public; this script
# never changes visibility or any setting beyond the build itself.
set -euo pipefail
cd "$(dirname "$0")"

../tools/lune run auto-checks.luau .
../tools/rojo build default.project.json --output game.rbxl
python3 ../../../custom-connectors/custom.roblox-open-cloud/bin/roblox_open_cloud.py publish-assets \
  --place-id 12693934119 --file game.rbxl
