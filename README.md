# Pet Tracker

Pet Tracker is a personal iOS app for tracking cat care events, reminders, saved autofill data, and notification-driven care routines.

The app is in early implementation. Stage 0 and Stage 1 are complete: the SwiftUI project shell exists, builds for the iOS Simulator, launches with sample data, and has tested domain, repository, and local persistence layers.

## Project Goals

- Build a native iOS app for personal pet care tracking.
- Store data only locally and/or in the user's iCloud.
- Avoid app-owned server-side state.
- Prioritize maintainable architecture from the beginning.
- Keep the code readable for a developer who is experienced with coding but new to mobile app development.
- Optimize the UI for quick repeated use on a phone.

## V1 Scope

Initial app scope includes:

- Pets with names and optional daily calorie goals.
- Food, litter, and medicine care events.
- Saved autofill options scoped by event type.
- Multi-pet food entry for the same food/time.
- Global/household events where appropriate.
- Reminders and notifications, including recurring schedules.
- Reminder completion that can optionally create care events.
- Small settings surface for notification preferences and default daily notification time.

Photos, Android support, user-defined event types, widgets, household sharing, and unit conversion are intentionally outside v1.

## Technical Direction

Current direction:

- Platform: iOS native only.
- UI: SwiftUI preferred.
- Minimum iOS target: iOS 17.0 for the initial scaffold.
- Persistence: architecture should support CloudKit/iCloud sync without forcing UI rewrites.
- Data layer: keep persistence behind repository/service boundaries.
- Local storage: SwiftData for pets, events, saved options, and reminders.
- Device-local storage: UserDefaults for notification settings.
- Notifications: use iOS local notification APIs, with app-level preferences where possible and system settings respected as overrides.

## Current App State

Implemented so far:

- Xcode project and SwiftUI app entry point.
- Tab shell for Home, Events, Pets, Reminders, and Settings.
- Domain model scaffolding for pets, care events, saved options, reminders, recurrence, and notification settings.
- Validation/calculation helpers for food and medicine payloads.
- Reminder scheduling helper for recurring reminders.
- Repository protocols with an in-memory implementation.
- SwiftData storage models, mappers, and repository implementations.
- UserDefaults-backed per-device settings storage.
- `PetCareStore` bridge with sample data seeding on first launch.
- Read-only starter views for the main tabs.
- Settings screen stub for notification preferences.
- Unit tests for validation, calorie calculation, recurrence scheduling, hard delete, soft delete, and reminder mute behavior.

The app now has local persistence. There is no event creation UI, notification scheduling, or iCloud sync yet.

## Setup and Run

Requirements:

- Xcode 26.5 or newer.
- iOS 26.5 Simulator platform installed in Xcode.
- SF Symbols app is useful for browsing Apple system icons.

Before first build after cloning:

```sh
cp PetTrackerApp/Services/SeedData.local.example.swift \
  PetTrackerApp/Services/SeedData.local.swift
```

Then edit `PetTrackerApp/Services/SeedData.local.swift` with your own development seed data. The local file is ignored by git and is used ahead of the public `SeedData.swift` seed.

Run in Xcode:

1. Open `PetTrackerApp.xcodeproj`.
2. Select the `PetTrackerApp` scheme.
3. Select an iPhone simulator.
4. Press `Cmd+R`.

Build from the command line:

```sh
xcodebuild -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData \
  build
```

The local `DerivedData/` directory is ignored by git.

Run tests from the command line:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

## Documentation

- [design.md](./design.md): product requirements, data model notes, user flows, and future work.
- [plan.md](./plan.md): staged build plan with tasks, learning notes, and acceptance checks.

## README Update Convention

Update this README when:

- The app's purpose or v1 scope changes.
- The technical direction changes.
- Major app capabilities are added.
- Setup/run/test instructions become available.
- The project reaches a new meaningful milestone.

Keep detailed requirements in `design.md` and detailed execution steps in `plan.md`. This README should stay short enough to orient someone quickly.

## Suggested Next Milestone

Move into Stage 2: tighten the read-only navigation and views on top of persisted data before adding writable forms.
