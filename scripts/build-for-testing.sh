#!/usr/bin/env bash
set -euo pipefail

PROJECT="PetTrackerApp.xcodeproj"
SCHEME="PetTrackerApp"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData}"

xcodebuild build-for-testing \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"
