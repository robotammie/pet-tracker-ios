#!/usr/bin/env bash
set -euo pipefail

PROJECT="PetTrackerApp.xcodeproj"
SCHEME="PetTrackerApp"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=$SIMULATOR_NAME}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData}"

# Resolve the actual destination so cleanup also follows DESTINATION overrides.
SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
destination = dict(part.split("=", 1) for part in sys.argv[1].split(",") if "=" in part)
devices = json.load(sys.stdin)["devices"]
matches = [device for runtime, entries in devices.items() for device in entries
    if device.get("isAvailable")
    and (device["udid"] == destination["id"] if "id" in destination
         else device["name"] == destination.get("name"))
    and (destination.get("OS", "latest") == "latest"
         or runtime.endswith("-" + destination["OS"].replace(".", "-")))]
if len(matches) != 1:
    sys.exit("UI tests require one unambiguous simulator destination; specify its id.")
print(matches[0]["udid"])
' "$DESTINATION")"

cleanup_test_runner() {
  # A test runner is not a standalone app and can crash when opened from Home.
  # Remove only its installation, never PetTracker or its persistent data.
  xcrun simctl uninstall "$SIMULATOR_ID" com.tammie.PetTrackerAppUITests.xctrunner \
    >/dev/null 2>&1 || echo "Warning: could not remove the UI-test runner from $SIMULATOR_ID" >&2
}

xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
trap cleanup_test_runner EXIT

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:PetTrackerAppUITests \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
