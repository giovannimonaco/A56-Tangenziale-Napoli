#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

scheme="${A56_TEST_SCHEME:-TangenzialeNapoli}"
case "$scheme" in
    TangenzialeNapoli|A56UI) ;;
    *) echo "Unsupported A56_TEST_SCHEME: $scheme" >&2; exit 2 ;;
esac

# Reuse the standalone regression checks on macOS as well as the iOS suite.
TZ=Pacific/Honolulu bash Tests/check-a56.sh

selection="$(python3 - <<'PY'
import json
import os
import re
import subprocess

def version(value):
    parts = tuple(int(part) for part in value.split('.'))
    return (parts + (0, 0, 0))[:3]

inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '-j']))
runtimes = [item for item in inventory['runtimes']
            if item.get('isAvailable') and '.iOS-' in item['identifier']]
runtime_override = os.getenv('A56_SIMULATOR_RUNTIME')
if runtime_override:
    runtimes = [item for item in runtimes if item['identifier'] == runtime_override]
if not runtimes:
    raise SystemExit('No available iOS Simulator runtime. Install one in Xcode Settings > Components.')
runtime = max(runtimes, key=lambda item: (version(item['version']),
                                         not bool(re.search(r'iPhone\d', item['identifier']))))
runtime_version = version(runtime['version'])
devices = [item for item in inventory['devicetypes']
           if item.get('productFamily') == 'iPhone'
           and version(item.get('minRuntimeVersionString', '0')) <= runtime_version
           and version(item.get('maxRuntimeVersionString', '65535')) >= runtime_version]
device_override = os.getenv('A56_SIMULATOR_DEVICE_TYPE')
if device_override:
    devices = [item for item in devices if item['identifier'] == device_override]
if not devices:
    raise SystemExit('No compatible iPhone Simulator device type found.')
# Prefer a standard Pro phone; fall back to any compatible iPhone.
device = max(devices, key=lambda item: (
    bool(re.fullmatch(r'iPhone \d+ Pro', item['name'])),
    version(item.get('minRuntimeVersionString', '0')), item['name']))
print(runtime['identifier'])
print(device['identifier'])
PY
)"
runtime="${selection%%$'\n'*}"
device_type="${selection##*$'\n'}"
simulator_id="$(xcrun simctl create 'A56 Tests' "$device_type" "$runtime")"

cleanup() {
    # Never use booted, shutdown all, or an existing developer simulator.
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

output="${A56_TEST_OUTPUT:-$PWD/.build/test-results/$(date -u +%Y%m%dT%H%M%SZ)-$$}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
echo "Testing on isolated A56 Tests simulator $simulator_id"
echo "Test artifacts: $output"

xcodebuild test \
    -project TangenzialeNapoli.xcodeproj \
    -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$output/DerivedData" \
    -resultBundlePath "$output/A56Tests.xcresult" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/xcodebuild.log"

xcrun xcresulttool get test-results summary --path "$output/A56Tests.xcresult" \
    > "$output/summary.json"
