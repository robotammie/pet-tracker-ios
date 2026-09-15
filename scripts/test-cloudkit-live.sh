#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "Set DEVICE_ID to a connected development iPhone identifier." >&2
  exit 2
fi

PROJECT="PetTrackerApp.xcodeproj"
SCHEME="PetTrackerApp"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedDataCloudKitLive}"

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:PetTrackerAppTests/CloudKitLiveIntegrationTests \
  -parallel-testing-enabled NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -DLIVE_CLOUDKIT_TESTS'
