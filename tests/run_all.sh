#!/bin/sh
# Runs every check. Needs: rojo, luau. First run downloads the Roblox API dump (~10 MB) to tests/mock/.
set -e
cd "$(dirname "$0")/.."
API=tests/mock/Full-API-Dump.json
if [ ! -f "$API" ]; then
	curl -sSL -o "$API" https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
fi
echo "== unit tests"
luau tests/run.luau
echo "== playtest (mock Roblox engine)"
python3 tests/mock/gen.py "$API" > /dev/null
luau tests/mock/play.luau
