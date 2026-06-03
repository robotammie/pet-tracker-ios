#!/usr/bin/env bash
set -euo pipefail

PROJECT="PetTrackerApp.xcodeproj"
SCHEME="PetTrackerApp"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData}"

xcrun simctl boot "$SIMULATOR_NAME" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_NAME" -b

xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
