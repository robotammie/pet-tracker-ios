# Pet Tracker

Pet Tracker is a personal iOS app for tracking cat care events, reminders, saved autofill data, and notification-driven care routines.

The app is in early implementation. Stages 0 through 5.10 are complete: the SwiftUI project shell exists, builds for the iOS Simulator, launches with sample data, persists locally with SwiftData, supports core event creation plus saved food/medicine options, has reminder completion/ignore behavior with best-effort local notifications, and includes focused notification settings.

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
- Small settings surface for notification preferences, per-event notification overrides, and default daily notification time.

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
- Sync plan: add CloudKit after the agreed Stage 5.7–5.9 local changes; try SwiftData CloudKit first while keeping repository boundaries as an escape hatch.

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
- Navigation and list views for Home, Events, Pets, Reminders, and Settings.
- Day-grouped event lists and pet detail sections with daily calorie totals.
- Home summary sections for overdue/upcoming reminders and recent care by category.
- Quick add flows for food, medicine, and litter care events.
- Food creation with household or multi-pet destination selection, locked saved-food units, and calculated calories.
- Medicine creation with multi-pet selection and per-pet dose entry.
- Litter creation with editable timestamp.
- Saved food and medicine option management from Settings, including soft delete, optional official food names, and medication purpose.
- Wet-food can units with fractional-can amounts and calories per can.
- Complete now checkmarks for due/upcoming reminders and a pet filter in Events.
- Historical event editing with explicit food calorie confirmation/recalculation.
- Health inside pet detail (Care / Health): weight, vet visits, procedures, and general notes, with pet-scoped add/edit/history and category filtering.
- Health last in Home Quick Add and included in chronological Recent; weight defaults to lb with kg also available.
- Entered medicine dose intervals, optional per-pet instructions, and same-medication/same-pet early-dose warnings with recorded override.
- Settings screen for global notification preferences, per-event notification overrides, and default daily notification time.
- Debug-only reset/reseed control for local development.
- Reminder completion, ignore-until, mute, and delete actions.
- Multi-pet reminder completion with per-pet completion state.
- Reminder-to-event completion that logs care events.
- Completed reminder history in the Reminders tab.
- Best-effort iOS local notification scheduling for active reminders.
- Saved medicine autoqueue for daily reminders.
- Unit tests for validation, calorie calculation, recurrence scheduling, hard delete, soft delete, reminder mute behavior, multi-pet reminder completion, and reminder persistence.

The app now has local persistence, core event creation, reminder actions, local notification scheduling, and notification settings. There is no iCloud sync yet. First launch loads development sample data, not an onboarding flow. Pets can be added from Pets > + and edited from pet detail > Edit Pet, with an optional daily calorie goal. Reminders > + creates pure or event-linked reminders with due style, recurrence, end date, and pet targets; swipe an active reminder to Edit. Completed history is preserved. Events > + opens the selected event type; swipe an event to Delete with confirmation. Logging forms offer Add new food/medication and select the saved result; Cancel preserves the previous selection. Stage 5.10 is complete, verified with 83 unit tests and all 21 UI tests.

To correct a historical event, open Events, choose a pet filter if needed, and tap the event. Food calories are edited explicitly; recalculation uses the rate stored with that event, when available. Editing an event leaves saved options and reminder history unchanged.

Configure dose timing in Settings → Saved Options → Medicine → an option. Enter the prescribed minimum and maximum hours (equal values for a fixed interval), or use pet-specific intervals. Early-dose warnings use the minimum; the maximum defines the displayed next-dose window. Cancel keeps the logging/editing form open without saving. Log anyway records the warning and acknowledgement time with affected events. With no interval configured, timing is not checked.

Use Home → Quick Add → Health to choose a pet and record a health entry. Pets → a pet → Health shows its history and category filter; the plus button adds an entry for that pet, and tapping an entry edits it. Health supports weight, vet visits, procedures, and general notes. Weight starts in lb; changing lb/kg retains the number without conversion. Recent includes the latest health entry for each pet/category over seven days, alongside care events.

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

During early development, SwiftData schema changes may require deleting local app data. In debug builds, use Settings > Development > Reset and Reseed Local Data to clear SwiftData records, reseed from the configured seed file, clear pending local notifications, and reset the app badge. Formal migrations should be added before relying on the app for real daily-use history.

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

Run unit tests from the command line (UI automation is excluded):

```sh
scripts/test.sh
```

The full test command has to launch the iOS Simulator test runner. The tests themselves are fast, but Xcode can spend a long silent stretch attaching to the simulator. For faster development checks:

```sh
scripts/build-for-testing.sh
```

Use this after code edits when you mainly need to confirm the app and test targets compile. It does not launch the simulator.

After a successful build, rerun tests without rebuilding:

```sh
scripts/test-without-building.sh
```

Run the separate UI smoke suite:

```sh
scripts/test-ui.sh
```

This builds and runs only `PetTrackerAppUITests`. It covers launch, food/medicine/litter logging, event editing and pet filtering, health Quick Add/Recent/history/edit/pet isolation, reminder completion, medication warnings/overrides, saved timing configuration, settings persistence, and the debug reset confirmation. Debug UI testing uses a separate SwiftData store and UserDefaults suite with public seed fixtures; each test resets that test data, while relaunch checks retain it. It never uses your private seed data or schedules notifications.

The UI-test script removes its test-runner installation after success or failure, leaving PetTracker and its data intact. Open `PetTrackerApp` for normal use; the test runner is not a standalone app and can crash when launched manually. UI tests invoked directly from Xcode may leave that runner installed.

All scripts accept `DERIVED_DATA_PATH`; test scripts also accept `SIMULATOR_NAME` (default `iPhone 17`) and `DESTINATION`. The UI-test script resolves its boot and cleanup device from `DESTINATION`; specify a simulator ID if its name is ambiguous. For other test scripts, set `SIMULATOR_NAME` to the explicit destination device too. `test-without-building.sh` reruns unit tests only and requires a successful build after the latest source edits.

For simulator or real-device reseeding, run a Debug build, then open Settings > Development > Reset and Reseed Local Data and confirm Reset and Reseed. This preserves notification preferences and reschedules active seeded reminders. Editing the seed file does not alter existing data until you reseed. If an incompatible schema prevents launch, delete the app from that simulator/device and reinstall; this also removes device-local settings. Release builds do not expose reset/reseed.

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

Stage 5.5 local polish is complete, with separate unit/UI test workflows, seven passing UI smoke tests, accessibility improvements, and reset/reseed documentation. Stage 5.6 small design updates are complete, verified with 44 unit tests and 8 UI tests. Stage 5.7 past-event editing and Stage 5.8 medication timing are complete. Final verification passed the app/test build, 61 unit tests, and all 13 UI tests. Stage 5.9 Health & Life is complete, verified with 68 unit tests and all 14 UI tests; [health-design-options.md](health-design-options.md) records the selected design. Stage 5.10 completes pet add/edit, general reminder forms, Events creation/deletion, and inline saved-option creation. Final build, 83 unit tests, and all 21 UI tests passed. Stage 6 CloudKit is next when requested. See `plan.md` for current verification results.
