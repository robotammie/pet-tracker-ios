# Pet Tracker Build Plan

This plan assumes the current direction in `design.md`: iOS native, SwiftUI-first, local/iCloud-owned data only, good architecture from the beginning, and enough explanation along the way for a developer new to mobile app work.

## Current Clarification Status
No clarification blocks planning. Current Stage 6.1–6.3 decisions:
- Archived care events are hidden from Events, Home Recent, pet history, and displayed calorie totals until restored.
- The Events tab toolbar provides View Archived for the currently selected event type and pet filter. Archived rows can be restored or permanently deleted.
- “Delete all” on a recurring reminder removes the active series and its completed reminder history.
- Automatic scheduled events initially support food/automatic-feeder entries only. Medicine continues to require reminder completion or manual logging.

Known choices:
- Build iOS native only for v1.
- Prefer SwiftUI.
- Design the data layer so CloudKit/iCloud sync can be supported without rewriting the UI.
- Add CloudKit after Stage 5 and a local-only polish pass.
- Stage 6 reviewed managed SwiftData sync and selected the explicit CloudKit fallback with a future shared-database path. Stage 6.3 adds one tested additive SwiftData model for automatic schedules. See sync-design.md.
- Treat food, litter, medicine, notifications, saved autofill options, pets, and settings as separate model concerns.
- Keep v1 settings focused on notification preferences and the global day-only notification time.
- Use hybrid notification settings: global controls first, with restrained per-event-type overrides.
- Add accessibility identifiers as UI is touched; add UI smoke tests during the local polish pass.
- During early development, reset/reseed after breaking schema changes; add formal migrations before real daily-use data matters.
- Include a debug-only reset/reseed tool now for faster simulator/device iteration.

## Test Workflow Notes
The XCTest bodies are currently fast, but iOS simulator test attachment can take 60-90 seconds and may look quiet while Xcode is waiting on the runner.

Use these helpers:
- `scripts/build-for-testing.sh` for day-to-day compile checks that do not need to run the simulator.
- `scripts/test-without-building.sh` after a successful build when rerunning unit tests only.
- `scripts/test.sh` to build and run unit tests only.
- `scripts/test-ui.sh` to build and run the separate UI smoke suite.
- Run both test suites for milestone verification.

The test helpers preboot the named simulator, disable parallel simulator destinations, and use the shared local `DerivedData/` directory.

## Stage 0: Project Foundation - Complete
Goal: create a clean iOS app skeleton that can grow without turning into a pile of view code.

Tasks:
- [x] Create a new iOS app project.
- [x] Use SwiftUI for the UI layer.
- [x] Choose initial minimum supported iOS version.
    - Current scaffold uses iOS 17.0.
- [x] Establish app module folders:
    - `App`
    - `Models`
    - `Persistence`
    - `Repositories`
    - `Services`
    - `Features`
    - `SharedUI`
    - `Tests`
- [x] Add basic dependency boundaries:
    - Views call view models or feature stores.
    - View models call repositories/services.
    - Persistence details stay out of views.
- [x] Add a small seed-data path for development previews and simulator testing.
- [x] Verify simulator build.
- [x] Verify simulator launch.

Mobile concepts to explain while building:
- SwiftUI app lifecycle.
- Navigation stack basics.
- State ownership: `@State`, `@Binding`, `@Observable`/view models, and why persistence should not leak everywhere.

Acceptance checks:
- [x] App launches in simulator.
- [x] Main navigation shell exists.
- [x] Project has a clear folder/module shape.
- [x] Sample data can render without real persistence.

Stage 0 notes:
- Project file: `PetTrackerApp.xcodeproj`
- App entry point: `PetTrackerApp/PetTrackerAppApp.swift`
- Main shell: `PetTrackerApp/App/AppTabView.swift`
- Sample store: `PetTrackerApp/Repositories/PetCareStore.swift`
- Preview data: `PetTrackerApp/Services/PreviewData.swift`
- Verified with:

```sh
xcodebuild -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData \
  build
```

Next stage: Stage 1.

## Stage 1A: Domain Model and Persistence Shape - Complete
Goal: define the core data model and repository boundaries before building screens that depend on them.

Confirmed decisions:
- Keep minimum iOS target at iOS 17.0.
- Use SwiftData-first architecture with repository boundaries.
- Add actual persistence in Stage 1B before moving to later app features.
- Notification presentation settings are per-device.
- Editing saved food/medicine options affects future events only; existing events keep their stored payload.
- Events are hard-deleted in v1.
- Notifications/reminders may be hard-deleted, and may also be muted so the user can keep them for later use.

Persistence approach options:

Option A: SwiftData first, with repository interfaces around it.

Pros:
- Lowest friction for an iOS-native app.
- Works naturally with Swift types and SwiftUI.
- Good local persistence story before sync is introduced.
- Can support CloudKit sync later if models are designed carefully.
- Easier to learn and debug incrementally than starting directly with CloudKit records.

Cons:
- SwiftData has its own modeling constraints and migration behavior.
- CloudKit compatibility still needs deliberate design.
- Some sync/conflict behavior can feel indirect because SwiftData abstracts storage details.

Option B: CloudKit-shaped models first, with local-only behavior during early development.

Pros:
- Forces early attention to sync constraints, stable IDs, record ownership, and CloudKit-compatible fields.
- May reduce later surprises when iCloud sync is added.
- Makes future sharing/sync boundaries more explicit.

Cons:
- More complexity before the app has many features.
- Slower learning curve for a first mobile app.
- More boilerplate around mapping and record-style thinking.
- Can over-optimize for sync before the local product model has settled.

Decision:
- Use Option A for v1: SwiftData-first architecture behind repository interfaces.
- Keep domain structs/enums clean enough that CloudKit compatibility can be added without rewriting views.

Tasks:
- [x] Define core entities:
    - `Pet`
    - `CareEvent`
    - `SavedEventOption`
    - `Reminder`
    - `UserSettings`
- [x] Define enums:
    - event type: food, litter, medicine
    - food type: wet, dry, treat
    - food unit: cup, oz
    - reminder mode: pure reminder, reminder to event
    - recurrence type: every N hours/days/weeks/months, N times per day
    - due style: timestamp, day-only
    - notification presentation settings: banner, sound, badge
- [x] Define typed payload structs for event data:
    - `FoodEventData`
    - `LitterEventData`
    - `MedicineEventData`
- [x] Add validation/sanitization helpers for each payload type.
- [x] Define reminder status values, including active, completed, and muted.
- [x] Define repository protocols for pets, events, saved options, reminders, and settings.
- [x] Keep Stage 1A using in-memory implementations so screens can continue to render while the model settles.

Mobile/data concepts to explain while building:
- Why mobile apps often separate domain models from storage models.
- Local persistence vs sync persistence.
- Why storing calculated calories on events is safer than recalculating old history.
- SwiftData basics and why it should sit behind repositories instead of being used directly from every view.

Acceptance checks:
- [x] Models compile.
- [x] Payload validation quietly drops unsupported/wrongly typed data.
- [x] Food calories are stored on event creation/update.
- [x] Unit conversion is not attempted in v1.
- [x] Reminder mute status is represented distinctly from delete.
- [x] Notification settings are represented as device-local settings.
- [x] Repository protocols exist before real persistence is added.
- [x] Tests cover calorie calculation, food validation, and reminder next-due calculation basics.

Stage 1A notes:
- Domain model: `PetTrackerApp/Models/DomainModels.swift`
- Validation/calculation helpers: `PetTrackerApp/Models/DomainValidation.swift`
- Reminder scheduling helper: `PetTrackerApp/Services/ReminderScheduler.swift`
- Repository protocols: `PetTrackerApp/Repositories/RepositoryProtocols.swift`
- In-memory implementation: `PetTrackerApp/Repositories/PetCareStore.swift`
- Tests:
    - `PetTrackerAppTests/DomainValidationTests.swift`
    - `PetTrackerAppTests/ReminderSchedulerTests.swift`
    - `PetTrackerAppTests/RepositoryTests.swift`
- Verified with:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

Result: 10 tests passed.

## Stage 1B: Local Persistence - Complete
Goal: replace the temporary in-memory store with local persistence before adding more feature flows.

Tasks:
- [x] Add SwiftData storage models.
- [x] Map between domain models and SwiftData models.
- [x] Implement repository protocols using SwiftData.
- [x] Decide which data belongs in SwiftData vs device-local settings storage.
    - Notification presentation settings are per-device and should not require iCloud sync.
- [x] Add local migration/versioning notes while the model is still small.
- [x] Keep CloudKit compatibility in mind, but do not enable iCloud sync yet.

Acceptance checks:
- [x] Pets, events, saved options, reminders, and applicable settings persist across app launches.
- [x] Existing sample/preview data path still works for previews and development.
- [x] Hard-delete behavior works for events.
- [x] Notifications can be hard-deleted or muted.
- [x] Saved option edits affect future events only.

Stage 1B notes:
- SwiftData storage models:
    - `PetTrackerApp/Persistence/SwiftDataModels.swift`
- Domain/storage mapping:
    - `PetTrackerApp/Persistence/SwiftDataMappers.swift`
- SwiftData repository implementations:
    - `PetTrackerApp/Persistence/SwiftDataRepositories.swift`
- Per-device settings storage:
    - `PetTrackerApp/Persistence/UserDefaultsSettingsRepository.swift`
- App persistence bridge:
    - `PetTrackerApp/App/PersistentRootView.swift`
- App startup now creates a SwiftData `ModelContainer` in `PetTrackerApp/PetTrackerAppApp.swift`.
- First launch seeds development sample data only when no pets exist.
- Current SwiftData records use stable IDs and mostly scalar fields to keep a later CloudKit migration approachable.
- CloudKit sync is still intentionally disabled.
- Tests:
    - `PetTrackerAppTests/SwiftDataPersistenceTests.swift`
- Verified with:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

Result: 14 tests passed.

## Stage 2: Core Navigation and Read-Only Views - Complete
Goal: make the app navigable and useful with sample data before adding forms.

Tasks:
- [x] Build primary navigation:
    - Home
    - Events by type
    - Pet detail
    - Notifications
    - Settings
- [x] Build homepage sections:
    - overdue reminders plus due/upcoming notifications through now + 24 hours
    - most recent action per category
    - due and recent categories both collapsible with temporary in-memory state
    - quick add buttons wired as no-op controls until Stage 3
- [x] Build event list views:
    - food events grouped by day
    - medicine events grouped by day
    - litter events grouped by day for consistency, without a dedicated litter history page for v1
- [x] Build pet detail:
    - pet-specific food and medicine events
    - global food events inside daily food groups with a global indicator
    - exclude global food from pet-specific calorie totals
    - show calorie totals by day in day headers
    - exclude litter cleaning events

Mobile/UI concepts to explain while building:
- SwiftUI lists and sectioned data.
- Empty states.
- Why mobile views should optimize for quick repeated actions.

Acceptance checks:
- [x] Sample data shows correctly on all main screens.
- [x] Global food appears on pet pages but does not affect daily calorie totals.
- [x] Litter cleaning does not appear on pet pages.
- [x] Navigation works comfortably on mobile-sized simulator screens.

Stage 2 decisions:
- Quick add buttons should be visible but no-op until Stage 3 event creation exists.
- Collapsed/expanded section state is temporary for Stage 2.
- Persisting collapsed/expanded section preferences should be considered in a later settings/polish stage.
- Home due/reminder section includes overdue reminders plus reminders due from now through the next 24 hours.
- Event lists use consistent day grouping across food, medicine, and litter.
- Pet detail day headers show daily calorie totals.

Stage 2 notes:
- Home screen added quick add controls and collapsible Due/Recent sections. Quick add was connected in Stage 3.
- Events screen groups all event types by day.
- Pet detail groups food/medicine by day, includes household food with a house indicator, excludes litter, and shows daily pet-specific calories in section headers.
- Shared row/date grouping helpers:
    - `PetTrackerApp/SharedUI/EventSummaryRow.swift`
    - `PetTrackerApp/SharedUI/ReminderSummaryRow.swift`
    - `PetTrackerApp/SharedUI/DateGrouping.swift`
- Verified with:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

Result: 15 tests passed.

## Stage 3: Event Creation and Saved Autofill Options - Complete
Goal: support the core logging workflows.

Food destination selection options:

Option A: One creation form with a destination dropdown containing Household and each pet.

Pros:
- One consistent food logging flow.
- Best match for shared meals where each cat gets a different amount.
- Makes saved food selection and timestamp entry happen once.
- Scales naturally to "Appa 2 cans, Tupo 1 can" without duplicate typing.
- Mode is derived from the selection state instead of a separate control.
- Selected pets can be toggled on/off directly.

Cons:
- More complex form state.
- The destination dropdown needs custom multi-select behavior.
- Standard SwiftUI menus may not provide enough room/clarity for selected-state highlighting.
- Validation has to account for household-vs-pet selection state.

Option B: Separate mode picker plus pet picker.

Pros:
- Easier to implement with standard controls.
- Makes the mode explicit.
- Validation is straightforward once the mode is chosen.

Cons:
- More taps and more concepts.
- Duplicates information because selected pets already imply one-pet vs multi-pet.
- More awkward when switching between one selected pet and several selected pets.

Decision:
- Use Option A for Stage 3: one food creation flow with a destination dropdown.
- Household is mutually exclusive with pet selections.
- Selecting Household clears selected pets.
- Selecting a pet clears Household.
- Selected pets are highlighted/checkmarked and can be tapped again to unselect.
- Amount fields appear after a saved/specific food is selected.
- Household shows one amount field.
- One selected pet shows one amount field.
- Multiple selected pets show one amount field per pet.
- Saved food selection locks the unit and calories-per-unit.
- Amount remains editable per event/per pet, and calories are calculated from amount x saved calories-per-unit.
- Food event calories are not manually editable when using saved food data.

Tasks:
- [x] Pre-step: add write-through creation plumbing:
    - repository-backed event/save-option write methods that update SwiftData and refresh in-memory state together
    - shared creation sheet/navigation entry point launched by the Stage 2 quick add controls
    - form view models for food, medicine, litter, and saved option editing
    - active saved-option filtering helpers scoped by event type
- [x] Build shared event creation flow shell:
    - event type routed from quick add
    - timestamp defaulted to now
    - editable timestamp
    - saved autofill selection for food and medicine
- [x] Build food creation:
    - household, one-pet, or multi-pet mode in one form
    - saved food dropdown
    - amount input for household/one-pet mode
    - per-pet amount input for multi-pet mode
    - locked unit from saved food
    - locked calories-per-unit from saved food
    - live calorie calculation from amount x calories-per-unit
    - allow amounts like 2 cans/units for a single logged event
    - multi-pet same-food/time creation
    - ignore blank/zero amounts in multi-pet creation
- [x] Build medicine creation:
    - pet required
    - saved medicine dropdown
    - dosage/unit required
    - multiple pets with per-pet dose, creating one event per pet
- [x] Build litter creation:
    - one-tap/global cleaning event
    - no pet selection
    - timestamp editable
- [x] Build saved option management:
    - list saved options by event type
    - add/edit options
    - edit existing options in place for future use
    - soft delete options

Mobile/UI concepts to explain while building:
- Form design on iOS.
- Pickers vs menus vs sheets.
- Input validation that helps without nagging.

Acceptance checks:
- Event and saved-option writes persist to SwiftData and update visible lists immediately.
- Events can be created for all v1 event types.
- Saved autofill options are scoped per event type.
- Saved food units/calories-per-unit are locked during event creation.
- Food event calories are calculated, not manually typed, when using saved food data.
- Multi-pet food creation creates one event per cat with a nonzero amount.
- Medicine multiple-pet creation creates one event per selected pet.
- Soft-deleted saved options stop appearing in creation forms.

Stage 3 pre-step notes:
- Store write-through helpers:
    - `saveCareEventAndRefresh`
    - `saveCareEventsAndRefresh`
    - `saveSavedOptionAndRefresh`
    - `softDeleteSavedOptionAndRefresh`
    - `activeSavedOptions(for:)`
- SwiftData repositories are attached to `PetCareStore` during app startup in `PersistentRootView`.
- Quick add buttons now open a shared creation sheet shell.
- Event creation scaffolding:
    - `PetTrackerApp/Features/EventCreation/EventCreationRoute.swift`
    - `PetTrackerApp/Features/EventCreation/EventCreationSheet.swift`
    - `PetTrackerApp/Features/EventCreation/FoodEventFormViewModel.swift`
    - `PetTrackerApp/Features/EventCreation/MedicineEventFormViewModel.swift`
    - `PetTrackerApp/Features/EventCreation/LitterEventFormViewModel.swift`
    - `PetTrackerApp/Features/EventCreation/SavedOptionFormViewModel.swift`
- Added tests for active saved option filtering and food destination selection behavior.
- Verified with:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

Result: 19 tests passed.

Stage 3 completion notes:
- Quick Add now opens working creation forms for food, medicine, and litter.
- Food creation:
    - Uses one destination menu containing Household plus each pet.
    - Household is mutually exclusive with selected pets.
    - Pet selections can be toggled on/off.
    - Saved food locks unit and calories-per-unit.
    - Household events create one global food event.
    - Multi-pet entries create one pet-specific event per nonzero amount.
- Medicine creation:
    - Requires a saved medicine and at least one selected pet.
    - Multiple selected pets create one event per pet with editable per-pet dose.
- Litter creation:
    - Creates a household litter event with editable timestamp.
- Saved option management:
    - Settings links to Food Options and Medicine Options.
    - Options can be added, edited in place for future events, or soft-deleted.
- New views:
    - `PetTrackerApp/Features/EventCreation/FoodEventCreationView.swift`
    - `PetTrackerApp/Features/EventCreation/MedicineEventCreationView.swift`
    - `PetTrackerApp/Features/EventCreation/LitterEventCreationView.swift`
    - `PetTrackerApp/Features/EventCreation/SavedOptionsListView.swift`
    - `PetTrackerApp/Features/EventCreation/SavedOptionEditorView.swift`
- New tests:
    - `PetTrackerAppTests/MedicineEventFormViewModelTests.swift`
    - `PetTrackerAppTests/SavedOptionFormViewModelTests.swift`
- Verified with:

```sh
xcodebuild test -project PetTrackerApp.xcodeproj \
  -scheme PetTrackerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath DerivedData
```

Result: 25 tests passed.

## Stage 4: Reminder and Notification Logic - Complete
Goal: get reminder behavior correct before worrying about final notification polish.

Tasks:
- [x] Implement reminder model and scheduling service.
- [x] Add option to autoqueue notifications/reminders when creating saved medicine data.
- [x] Support pure reminder vs reminder-to-event.
- [x] Support recurrence:
    - every N hours
    - every N days
    - every N weeks
    - every N months
    - N times per day with suggested editable default times
- [x] Support timestamp vs day-only due style.
- [x] Use global default day-only display time, defaulting to 9:00 AM.
- [x] Keep overdue reminders visible until completed, ignored, muted, or deleted.
- [x] Add ignore-until behavior.
- [x] Add completion flow:
    - completion time defaults to now
    - user may edit completion time
    - recurring next due time is based on completion time
    - reminder-to-event completion can create/log the event
- [x] Support optional schedule end date.
- [x] Stop medicine reminders automatically at schedule end date.
- [x] Add multi-pet reminder groups with per-pet completion state.
- [x] Keep a completed history entry for recurring reminders while scheduling the next active occurrence.
- [x] Add best-effort iOS local notification scheduling for active reminders.

Mobile concepts to explain while building:
- Local notifications on iOS.
- App-level preferences vs iOS system notification settings.
- Why scheduling and visible reminder state are related but not identical.

Acceptance checks:
- [x] Reminder next-due tests cover normal, late, and edited-completion cases.
- [x] Day-only reminders schedule at the configured morning time.
- [x] Ignored reminders update due date and leave history intact as needed.
- [x] Reminder-to-event completion creates the expected care event.
- [x] Partial multi-pet completion keeps the reminder active until all pets are complete.
- [x] Multi-pet reminder target data persists locally.

Stage 4 notes:
- Multi-pet reminders use one reminder with per-pet target completion state.
- Completing selected pets logs only those pets' events for reminder-to-event reminders.
- Recurring reminders create a completed history copy and keep the original reminder active with the next due date.
- Ignore Until includes quick presets, custom date/time, and an Update Future Notifications toggle for recurring reminders.
- Completed reminders appear in an auto-collapsed Completed section in the Reminders tab.
- Local notification scheduling is best-effort and syncs pending iOS notifications from active reminders.
- Saved medicine creation can optionally autoqueue a daily reminder for selected pets.
- Tests:
    - `PetTrackerAppTests/ReminderActionServiceTests.swift`
    - `PetTrackerAppTests/ReminderSchedulerTests.swift`
    - `PetTrackerAppTests/SwiftDataPersistenceTests.swift`
- Verified with:

```sh
scripts/build-for-testing.sh
scripts/test-without-building.sh
```

Result: 30 tests passed.

## Stage 5: Settings - Complete
Goal: expose the small set of v1 settings without turning settings into a junk drawer.

Tasks:
- [x] Build settings view.
- [x] Add global notification presentation preferences:
    - banner
    - sound
    - badge
- [x] Add optional per-event-type notification presentation preferences.
- [x] Add global default day-only notification time.
- [x] Make reminder scheduling read from these settings.
- [x] Make clear in implementation notes that iOS system settings can override app-level notification behavior.
- [x] Add debug-only reset/reseed control for local development.
- [x] Add accessibility identifiers to touched settings controls.

Mobile concepts to explain while building:
- UserDefaults vs persisted app data.
- Which settings belong locally vs in iCloud.
- iOS notification permission and presentation constraints.

Acceptance checks:
- [x] Settings persist across app launches.
- [x] Default daily notification time affects new day-only reminders.
- [x] Per-event-type presentation preferences override global preferences where set.
- [x] Debug reset clears local SwiftData records, reseeds from configured seed data, clears pending notifications, and resets the badge.

Stage 5 notes:
- Settings now show global notification presentation controls first.
- Food, Litter, and Medicine notification overrides are available in collapsed sections.
- Each event type has a Customize toggle; turning it off removes the override and falls back to global settings.
- Notification preferences remain per-device in UserDefaults.
- Debug builds include a Settings > Development reset/reseed button with destructive confirmation.
- Debug reset keeps app-level settings, clears SwiftData-backed app data, reseeds from `SeedData.local.swift` when present, clears pending local notifications, resets the badge, then schedules active seeded reminders.
- Tests:
    - `PetTrackerAppTests/LocalNotificationServiceTests.swift`
- Verified with:

```sh
scripts/build-for-testing.sh
scripts/test-without-building.sh
```

Result: 38 tests passed.

## Stage 5.5: Local Polish Before CloudKit - Complete
Goal: make the local-only app comfortable enough for daily testing before adding sync complexity.

Tasks:
- [x] Align README, plan, and handoff with actual app behavior and test workflows.
- [x] Add small UI smoke tests for launch, food/medicine/litter logging, reminder completion, settings persistence, and debug reset confirmation.
- [x] Add/refine identifiers on controls and reminder rows; remove container identifiers that override children.
- [x] Review empty states and first-run sample seeding; add guidance when food/medicine options are missing.
- [x] Review touch targets and Dynamic Type; expand destination and input touch areas and stack reminder/amount/dose content at accessibility sizes.
- [x] Document simulator/device reset/reseed and incompatible-schema reinstall.
- [x] Keep unit testing separate from UI automation.

Acceptance checks:
- [x] Core local happy paths persist correctly and pass smoke tests.
- [x] UI smoke suite remains focused, without dependence on private seed data or prior development data.
- [x] Schema-reset expectations and current feature limits are documented before CloudKit work.

Stage 5.5 notes:
- Debug UI automation uses a separate persistent SwiftData store (`UITests.store`) and UserDefaults suite (`PetTrackerApp.UITests`). Public seed fixtures begin with no event history. `-uiTestingReset` resets only the test data; relaunch checks omit it. A no-op notification scheduler avoids prompts and notification side effects.
- `scripts/test.sh` and `scripts/test-without-building.sh` select only unit tests. `scripts/test-ui.sh` builds and runs only UI tests. `SIMULATOR_NAME` now drives the default destination too.
- At this Stage 5.5 checkpoint, pet editing and general reminder creation/editing remained unimplemented; these were subsequently included in Stage 5.10. First launch still seeds sample data.
- Visual review on iPhone 17 / iOS 26.5 checked Home, settings, and the food form at the largest accessibility text size. Reminder titles and due times now stack without narrow-column wrapping. The original simulator text size was restored. This is a focused simulator review, not an exhaustive VoiceOver or real-device audit.
- Verified on 2026-09-13:
    - `scripts/build-for-testing.sh`: app and both test targets compile.
    - `scripts/test-without-building.sh`: 38 unit tests passed; no UI tests launched.
    - Final `scripts/test-ui.sh`: all 7 UI tests passed in about 140 seconds of test execution (149 seconds including test setup/cleanup).
    - Script syntax checks and `git diff --check` passed.
- Initial UI runs exposed container-ID propagation and dialog/menu behavior; those were fixed and the final full suite passed.

Historical Stage 5.5 checkpoint; this work was subsequently committed with Stages 5.6–5.9 as `5151299`.

## Stage 5.6: Small Design Updates - Complete
Goal: implement small requested changes before CloudKit.

Implemented scope:
- Complete now checkmark controls on Home Due and Reminders Active rows, using now for event/completion time and completing all remaining pet targets.
- Events pet filter: All pets (including Household), Household, or one pet's own events.
- Wet-food can units and fractional-can calorie calculation.
- Optional official food name and medication purpose in saved options, domain models, and SwiftData mapping.
- Preserve an existing medicine cadence when editing metadata.
- Focused unit coverage for completion time/remaining targets, pure reminders, pet filtering, can validation/calories, metadata persistence, and unchanged event snapshots.
- UI coverage for Home Complete now and pet filtering, retaining Stage 5.5 smoke paths.

Verification on 2026-09-13:
- `scripts/build-for-testing.sh`: build passed.
- `scripts/test.sh`: 44 unit tests passed.
- `scripts/test-ui.sh`: all 8 UI tests passed, including Complete now and Events pet filtering (about 167 seconds test execution).
- `git diff --check`: passed.

This checkpoint was subsequently committed as part of `5151299`. The user subsequently authorized Stages 5.7–5.8 and requested design options only for 5.9.

## Stage 5.7: Past-Event Editing - Complete
Authorized 2026-09-13 and verified before starting 5.8.

- Typed single-event editor launched from Events rows, preserving ID, createdAt, and original historical payloads.
- Date/time, pet/Household scope, name, food type/amount/unit/calories, and medicine dose/unit edits.
- Optional stored calorie-rate snapshot on newly logged food; explicit recalculation only when the original rate matches the selected unit. Older entries retain user-confirmed calories.
- Validated subtype values; repository upsert refreshes grouping and daily calorie totals.
- Event edits leave saved options and reminder completion history unchanged.

Verification: 48 unit tests passed (`/tmp/pettracker-57-unit.log`); focused food-edit/relaunch/cancel UI test passed (`/tmp/pettracker-57-ui.log`).

## Stage 5.8: Medication Timing - Complete
Authorized 2026-09-13; same medication + cat only, as explicitly chosen by the user.

Implemented scope:
- Structured minimum/maximum prescribed hours, optional pet-specific overrides, stable medication IDs on events and reminder payloads.
- Checks against proposed timestamps and nearest earlier/later doses, excluding IDs being edited and including all batch candidates.
- One deferred write gate for manual logging, event edits, selected-target reminder completion, and Complete now. Cancel writes no events or reminder changes; Log anyway records warning text and acknowledgement time for affected events.
- Scoped warning presentation on the initiating sheet or root surface, with dismissal only after a completed save.
- Optional SwiftData fields and legacy payload decoding; unique normalized legacy names link only when exactly one saved medication (including deleted options) matches. Ambiguous matches require acknowledgement; unrelated/unknown names make no safety assertion.
- Current configured prescription overrides an event's timing snapshot for checks; historical name/dose/unit remain unchanged. Without a current matching option, the stored linked interval is used.
- No clinical defaults and no different-medication interactions. Interaction checks have been removed from scope at the user’s request.

Final verification on 2026-09-13:
- `scripts/build-for-testing.sh`: app and both test targets built successfully (`/tmp/pettracker-58-build-final.log`).
- `scripts/test.sh`: 61 unit tests passed after the timing/editor changes; final `scripts/test-without-building.sh` confirmed all 61 against the final build (`/tmp/pettracker-58-unit-verified.log`).
- `scripts/test-ui.sh`: all 13 UI tests passed in 366 seconds (`/tmp/pettracker-58-ui-verified.log`). Includes manual Cancel/Log anyway and persisted override, editor warning, Home Complete now, selected-target reminder completion, entered interval/relaunch persistence, and existing smoke paths.
- `git diff --check` and shell script syntax checks passed.

Initial UI failures identified sheet warning presentation and an ambiguous Settings selector. Both were fixed; the final full suite passed. Stages 5.7–5.8 were subsequently committed in `5151299`.

## Stage 5.9: Health & Life - Complete
Approved 2026-09-13: option A in pet detail; Health last in Quick Add; include health in Recent; smaller initial category set. Weight defaults to lb, with kg also available.

- Separate HealthEntry/typed weight, repository, and SwiftData record.
- Required-pet add/edit forms for weight, vet visits, procedures, and general notes.
- Pet detail Care / Health picker; Health date grouping, category filtering, empty state, and add button.
- Mixed chronological Recent with latest-per-pet/category health entries from the last seven days and links to pet Health.
- Preserve original unit and edit identity; no impact on care calories or reminder history.
- Save errors retain the editor; reset/reseed includes health records.
- Unit/disk persistence coverage and Quick Add/Recent/pet isolation/edit/relaunch UI coverage.

Verification on 2026-09-13:
- App/test build passed (`/tmp/pettracker-59-build-final.log`).
- All 68 unit tests passed (`/tmp/pettracker-59-unit-verified.log`), including seven Health tests for validation, edit identity, unit preservation, Recent grouping, care isolation, save failures, and all-category disk persistence.
- Focused Health UI test passed (`/tmp/pettracker-59-ui-picker.log`): required pet, lb default, Quick Add, Recent links, edit/relaunch, category filtering, canceled edits, and pet isolation.
- All 14 UI tests passed with zero failures in 472 seconds (`/tmp/pettracker-59-ui-final.log`; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.13_16-07-34--0700.xcresult`). Existing logging, reminders, medication warnings, edits, and Settings remain green.
- Initial UI test failures were resolved by correcting numeric-text replacement and tapping the pet picker's visible selection value, waiting for its choice before selecting. The focused Health test and final full suite both passed afterward.
- Simulator visual inspection confirmed Health last in Quick Add, the mixed Recent row, and the unchanged five-tab layout. `git diff --check` passed.

Approved design is in `health-design-options.md`. Follow-up reminders, charts, attachments, and integrations are deferred. Medication interaction checks are removed from scope. The user requested committing Stages 5.5–5.9 after changing litter icons to `tray`; the icon-only update is included in that commit. CloudKit remains Stage 6, to be started when requested.

## Pre-Stage 6 review (2026-09-13)

Completed local scope is verified and committed as `5151299`. No unanswered choices remain for Stages 5.6–5.9. The approved Health scope and explicitly deferred features remain unchanged; medication interaction work is excluded.

The original-design gaps reviewed before Stage 5.10 were: pet add/edit, general reminder creation/editing, direct Events creation actions, inline saved-option creation/save-update, and care-event deletion UI. See design.md's implementation boundary for current alternatives and the Stage 3 food-field decision. The user reviewed each gap and approved the minimal versions below before Stage 6. Their approved minimal versions are complete and verified in Stage 5.10.

Do not reset/reseed personal history to make a CloudKit schema change pass. Prove an upgrade path on a copy of a populated local store before enabling sync. Current repositories swallow many fetch/save errors; error reporting and recoverable container startup must be included in sync readiness, so failure is not mistaken for an empty database.

## Stage 5.10: Remaining Local Workflows - Complete

The user approved all five items individually before Stage 6. The plan was committed as `ebe568a`; implementation is complete and verified:

1. **Pet add/edit:** name and optional daily calorie goal. Preserve the pet ID and linked history on edit. Pet deletion is deferred.
2. **General reminder creation/editing:** title, pure reminder or event-linked mode, due timestamp/day-only, recurrence, optional end date, and applicable pets/targets. Preserve completed history when editing an active definition.
3. **Events creation:** a + button opens the existing creation form for the selected event type.
4. **Care-event deletion:** swipe-to-delete with confirmation for food, medicine, and litter. Refresh visible history/totals immediately; leave reminder completion history unchanged.
5. **Inline saved-option creation:** Add new food/medication opens the existing saved-option editor, then selects the newly saved option on return. Cancel leaves the previous selection unchanged. Food unit/calorie rate remain locked during logging. The broader save/update checkbox behavior is deferred.

Implement and test each workflow before proceeding to the next. Verify ID/history preservation, canceled actions, persistence after relaunch, creation routing, deletion totals, and new-option selection. Run the full unit/UI suites for milestone completion. Do not begin Stage 6 until this local milestone is complete.

Verification on 2026-09-13:
- Pet workflow: 71 unit tests and focused add/edit/Cancel/relaunch UI test passed before reminder implementation (`/tmp/pettracker-510-pet-unit.log`, `/tmp/pettracker-510-pet-ui.log`).
- Reminder workflow: 78 unit tests passed, then eight reminder-specific tests passed after the added-pet fix; both creation/edit/Cancel/relaunch and medication-reminder completion UI tests passed (`/tmp/pettracker-510-reminder-unit.log`, `/tmp/pettracker-510-reminder-focused.log`, `/tmp/pettracker-510-reminder-ui-retry.log`). Final reminder coverage has nine passing tests, including option clearing/history restoration.
- Events + routing passed its focused UI test (`/tmp/pettracker-510-events-add-ui.log`).
- Deletion: both unit tests and the focused Cancel/confirm/relaunch UI test passed (`/tmp/pettracker-510-delete-focused-retry.log`, `/tmp/pettracker-510-delete-ui-final.log`).
- Inline medication: factory/dose-identity coverage and save/select/Cancel/relaunch UI passed (`/tmp/pettracker-510-inline-focused.log`, `/tmp/pettracker-510-inline-ui-retry.log`). Inline food and all nine reminder tests passed after full-row touch-target and option-clearing fixes (`/tmp/pettracker-510-inline-food-hitarea.log`).
- Final app/test build passed (`/tmp/pettracker-510-build-final.log`). All 83 unit tests passed (`/tmp/pettracker-510-unit-final.log`; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.13_17-01-45--0700.xcresult`).
- All 21 UI tests passed with zero failures in 728 seconds (`/tmp/pettracker-510-ui-final.log`; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.13_17-02-07--0700.xcresult`).
- Initial test issues were corrected using captured UI evidence: menu visibility/scrolling, nested alert actions, stepper increment identifier, zero replacement, and Home versus Events food-row text. Inline Add new labels now have explicit full-row touch targets after intermittent row taps failed to dispatch.
- Simulator screenshots confirmed inline editor layout and preserved food selection/amount after Cancel. `git diff --check` passed. Implementation and documentation are included in the requested Stage 5.10 commit. Pet deletion, broader saved-option save/update controls, and other approved future features remain deferred. Stage 6 was subsequently authorized; see its status below.



## Stage 6: iCloud/CloudKit Sync

Status: complete. Implementation, Development provisioning, physical-device live CloudKit validation, and final regressions passed on 2026-09-15.

Goal: connect persistence to iCloud once local behavior is stable.

Architecture constraints retained through completion:
- Developer account setup is complete. Team `UXV29Z3R2F`, bundle `com.tammie.PetTrackerApp`, and container `iCloud.com.tammie.PetTrackerApp` are configured for Development.
- Keep local behavior and test isolation usable independently of CloudKit. Signed Debug app builds enable Development sync; XCTest/UI hosts remain cloud-disabled; Release remains local-only until production schema deployment.
- Future multi-user/household sharing remains a goal. Review sync architecture against that goal before choosing the final integration approach: preserve stable IDs, keep account/database/record ownership and sharing concerns behind repository/sync boundaries, and avoid making the UI or domain logic depend on a single user's private database. Evaluate whether the proposed SwiftData-first approach leaves a workable sharing path; retain an explicit CloudKit option if needed. Sharing UI, invitations, and permissions are future scope, not Stage 6 implementation requirements.

Tasks:
- [x] Configure the signing team, iCloud/CloudKit entitlements, Development container, and reusable template.
- Review SwiftData CloudKit integration first: completed; use the explicit fallback described in sync-design.md for deterministic reconciliation and future zone sharing.
- Keep repository and sync transport boundaries strict.
- Map local persistence models to CloudKit-compatible records or SwiftData CloudKit configuration.
- Validate sync behavior for:
    - pets
    - care events
    - health entries
    - saved options
    - reminders and per-pet reminder targets
- Keep all current notification settings in device-local UserDefaults, including presentation overrides and day-only notification time.
- Handle iCloud unavailable/signed-out state gracefully.
- Audit every SwiftData record before enabling sync: unique constraints, required attribute defaults/optionality, and any relationships. Preserve stable domain IDs with an application-level identity/reconciliation strategy. Current records use `@Attribute(.unique)`; CloudKit does not support enforcing this option. See [Apple: syncing model data](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
- Verify a data-preserving local-store upgrade with populated care, Health, saved options, and reminder history; add versioned schema/migration where needed.
- Replace seed-on-empty behavior with an initialization strategy that cannot duplicate personal/sample data while an existing iCloud dataset is downloading. Keep UI-test stores and debug resets isolated from iCloud.
- Refresh PetCareStore and reschedule local notifications when remote changes arrive or the app returns to the foreground; reconcile deletions as well as inserts/edits.
- Define conflict behavior for simultaneous edits, delete versus edit, and concurrent reminder completion. Prevent duplicate events/history/next occurrences; test partial multi-pet completion across devices.
- Surface local fetch/save/container errors with a recoverable offline path rather than silently treating failure as no data.
- Confirm signing team, iCloud container access, and two usable same-account test contexts before claiming sync verification.

### Stage 6 code-readiness implementation (2026-09-13)

The SwiftData-first review selected the planned explicit CloudKit fallback. See [sync-design.md](sync-design.md) for the decision, wire contract, durability, conflicts, scoped ownership, future sharing, and activation procedure.

- Implemented mapping for pets, care events, Health, saved options, and reminder definitions/targets/completions. Local SwiftData schema and stable IDs are preserved; managed CloudKit mirroring is explicitly disabled. A populated Stage 5 store-copy upgrade test preserves all six record types.
- Added a durable prepared-write journal, exact-version acknowledgements, account/container/environment scope, tombstones, deterministic edit conflicts, and recovery before network metadata operations.
- Concurrent reminder completion merges target outcomes into one logical event/history/next occurrence; repeated submissions, partial multi-pet completion, historical edits/deletions, scheduling calendars, newer definition edits, and stale sheets are covered by tests.
- Implemented paginated full-zone CloudKit catch-up, optimistic writes/conflict retry, foreground/manual/local-write sync, and active minute polling. Imported changes refresh the store and local notifications. Background push, incremental fetch optimization, and sharing UI remain future scope.
- Replaced swallowed fetch/save errors and fatal container startup with surfaced retry paths and atomic local transactions. Invalid/lossy imports roll back. Cloud-configured startup does not auto-seed; test hosts have separate stores/defaults and cannot enable CloudKit. Cloud-configured debug reset is unavailable.
- Configured signed Debug builds for the actual Development container and retained reusable template files. Release remains local-only until its schema is deployed.

Local verification (2026-09-13):

- Normal app/unit/UI build passed: `/tmp/pettracker-6-verified-build.log`.
- Optional CloudKit-flagged, unsigned template build passed: `/tmp/pettracker-6-cloudkit-final-build.log`. Its unit run verified test-host isolation and found one calendar assertion comparing unspecified minutes with canonical zero minutes; the assertion now compares canonical payloads without changing the recurrence/time-zone check.
- Final normal-build unit run: **111 tests, 0 failures**. Log `/tmp/pettracker-6-verified-unit.log`; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.13_18-46-34--0700.xcresult`.
- Full UI regression: **22 tests, 0 failures**, including failed-startup retry preserving existing test history. Log `/tmp/pettracker-6-full-ui.log`; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.13_18-28-35--0700.xcresult`. Subsequent changes were sync validation/canonicalization and unit-host isolation, with the local UI behavior unchanged.
- Latest normal app installed and launched successfully on iPhone 17; Home screenshot showed no startup failure. The UI runner was removed; only the current app bundle remains on that simulator. Other simulators/personal data were not reset for Stage 6.
- These checks establish the local/model baseline; live evidence is recorded below.

Stage 6 live acceptance checks are complete. Production schema deployment remains Stage 7 release work.

Live verification and final regression (2026-09-15):

- Xcode automatic signing produced an Apple Development profile with the expected app identifier and iCloud container entitlements. The Development schema contains `PetTrackerEntityV1.envelope`.
- The signed app on the connected iPhone saved the populated personal dataset to the real Development container. Before direct simulator replacement, aggregate verification found 2 pets, 3 care events, 3 Health entries, 1 reminder, and 2 saved options on both phone and simulator.
- `CloudKitLiveIntegrationTests` passed on physical iPhone in **7.288 seconds** against a uniquely named temporary private Development zone. Two independent local contexts verified all synced categories, empty-context download without seeds, offline edit/reconnect, and concurrent partial reminder completion with converged snapshots and no duplicate logical result. Result: `DerivedDataCloudKitLive/Logs/Test/Test-PetTrackerApp-2026.09.15_12-17-39--0700.xcresult`.
- Final unit regression: **111 tests, 0 failures**. Result: `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.15_12-01-13--0700.xcresult`.
- Final UI regression: **22 tests, 0 failures**, including the medication alert paths. Result: `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.15_12-01-51--0700.xcresult`.
- The iPhone 17 simulator could not use CloudKit because its iCloud protected-key state reported `waitfortrust`/`PCSNoPublicIdentity`. Security settings were not weakened. Its app data was replaced directly with a verified copy of the phone data; that local copy is separate from live CloudKit evidence.
- The app retries after `CKAccountChanged` as well as foreground entry, local writes, manual Sync Now, and active polling. Future household sharing remains isolated behind scope/database/zone boundaries; sharing UI and permissions remain future work.

Mobile/sync concepts to explain while building:
- CloudKit containers and entitlements.
- Offline-first behavior.
- Sync conflicts and why timestamps/IDs matter.

Acceptance checks:
- Data persists locally.
- Data syncs between two simulator/device contexts where feasible.
- App remains usable when iCloud is unavailable.
- Existing populated local data survives the upgrade; empty second-device startup does not create duplicate seeds.
- Imported Health/care edits and deletions update visible screens without relaunch; notification schedules follow imported reminder changes.
- Concurrent reminder completion produces one logical completion/event and consistent per-pet state.
- UI automation continues to use cloud-disabled test data; current unit/UI regression suites pass.
- No server-side app state is introduced.

## Stage 6.1: Event History Actions - Planned

Goal: make logged events easier to manage from the Events tab without losing useful history accidentally.

Tasks:
- Add an optional `archivedAt` value to care events and their SwiftData/CloudKit representation. Keep the change backward compatible so existing local and synced events remain active.
- Add an Archive swipe action to each event on the main Events page.
- Hide archived events from the normal Events list, Home Recent, pet history, and displayed calorie totals.
- Add View Archived to the Events tab toolbar. It shows archived events for the currently selected event type and pet filter, preserving the familiar Food/Medicine/Litter and pet context.
- Give archived rows Restore and permanent Delete actions. Restore clears `archivedAt` and returns the event to normal history and totals.
- Keep the existing main-page swipe Delete action and confirmation. Deletion remains permanent and leaves reminder completion history unchanged.
- Add Duplicate to the event editor/action menu. Start from the historical event snapshot, assign a new event ID and creation time, and require a new event timestamp that defaults to now.
- Run duplicated medicine events through the existing same-medication/same-cat timing warning and override flow before saving.
- Ensure archive, restore, delete, and duplicate writes refresh visible history/calorie totals immediately and sync through the existing journal/tombstone path.

Acceptance checks:
- Archiving removes an event from normal history, Recent, pet history, and displayed totals without deleting its stored payload.
- View Archived respects the selected event type and pet filter; Restore returns an event to the corresponding normal views and totals.
- Deleting from the main Events page still requires confirmation and persists after relaunch/sync.
- Duplicate preserves type, pet/household scope, and stored payload while using a new ID and user-selected timestamp.
- Canceling archive/delete/duplicate leaves the original event unchanged.
- Archive state and duplicated events converge without duplicates in two sync contexts.
- Focused unit and UI tests pass before Stage 6.2 begins.

Planning note: the current Events page already provides confirmed swipe deletion. This stage retains and regression-tests it while adding archive/restore and duplication.

## Stage 6.2: Reminder Row Editing and Recurrence Deletion - Complete

Goal: make reminder editing discoverable and let a recurring series skip one occurrence or stop future occurrences.

Tasks:
- Make selecting an active reminder row open the existing reminder editor. Retain the swipe Edit action as an alternate entry point.
- Keep completed history read-only.
- Replace immediate swipe deletion with a confirmation flow.
- For a nonrecurring reminder, offer Delete Reminder.
- For a recurring reminder, offer:
    - Delete This Occurrence: remove/skip the displayed occurrence and advance the same series to its next due time without creating completion history or an event.
    - Delete All: delete the active series, all completed history belonging to that series, and its pending local notifications. Care events previously created by completing the reminder remain independent historical events.
- Calculate the next occurrence from the skipped occurrence's scheduled due time and existing calendar/recurrence rule so a late deletion does not shift the cadence to the deletion time.
- Add or preserve a stable series identity on active and completed reminder records so Delete All can remove only history belonging to that series.
- Use the existing sync write/tombstone rules so two devices cannot recreate a skipped occurrence or deleted series/history.

Acceptance checks:
- Tapping an active row opens its editor and Cancel makes no changes.
- Deleting a single nonrecurring reminder removes it and its scheduled notification.
- Deleting one recurring occurrence advances exactly once, creates no care event, and survives relaunch/sync.
- Delete All removes the active series, its notifications, and its completed reminder history while retaining care events already logged from those completions.
- Concurrent skip/edit/delete behavior converges deterministically in two sync contexts.
- Focused unit and UI tests pass before Stage 6.3 begins.

Implementation (2026-09-15): active reminder rows open the existing editor and retain swipe Edit. Deletion now confirms nonrecurring removal or offers Delete This Occurrence / Delete All for recurring reminders. A skipped occurrence advances from its stored due time and creates neither completion history nor a care event. Its deterministic sync record prevents a concurrent stale edit from restoring that due instant. Deterministic history identities let Delete All remove only the series history; care events remain independent. Existing journal tombstones make series deletion win concurrent edits and suppress completion replay.

## Stage 6.3: Automatic Scheduled Events - Complete

Goal: support events that are expected to happen automatically, such as an automatic feeder delivery, without showing a reminder or requiring completion.

Architecture decision:
- Model an automatic event schedule as its own synced domain entity rather than disguising it as an active reminder. It can reuse the reminder editor's event-payload and recurrence controls, but it has no notification, completion, ignore, mute, or completed-reminder history.
- iOS does not guarantee that arbitrary app code runs at an exact scheduled minute. The app will materialize overdue occurrences on launch, foreground refresh, successful sync, and local schedule writes. Each created event records the intended scheduled timestamp even if materialization happens later.
- Give each occurrence a deterministic identity derived from schedule ID plus scheduled timestamp. This prevents duplicate events when multiple devices materialize the same occurrence.

Initial scope:
- Add a Scheduled Events section and add/edit/delete controls in the Reminders tab.
- Support timestamp recurrence and optional end dates using the existing recurrence rules and calendar semantics.
- Reuse stored event payload snapshots so later saved-option edits do not rewrite a schedule unexpectedly.
- Start with food schedules for automatic feeder use. Medicine remains reminder/manual logging because an unattended automatic write cannot present the medication timing warning or prove a dose was administered.
- Materialize all unrecorded due occurrences in chronological order, with a bounded batch and resumable cursor for long periods away from the app.
- Store last-materialized metadata and deterministic occurrence IDs in SwiftData and the versioned CloudKit envelope. Preserve offline operation and future household scope boundaries.
- Clearly explain in the UI that an event may appear when the app next runs, but its logged time is the scheduled delivery time.

Acceptance checks:
- A due schedule creates one event with the scheduled timestamp and no reminder or notification.
- Repeated foreground/sync processing and processing from two devices do not duplicate an occurrence.
- Editing a schedule affects future occurrences only; past generated events retain their snapshots.
- Deleting a schedule stops future generation without deleting events already created from it.
- Offline missed occurrences catch up after the app runs again, in order, without shifting the recurrence cadence.
- Existing reminder, event, medication-warning, local-notification, and CloudKit regression suites remain green.

Implementation (2026-09-15): added a food-only `ScheduledEvent` domain entity, additive SwiftData record/repository, version-1 sync payload, journal mapping, and Reminders-tab add/edit/delete UI. Due occurrences materialize on launch, foreground refresh, successful sync, and schedule saves. The cursor advances chronologically in bounded, resumable batches using the stored calendar. Each generated event uses a deterministic schedule/timestamp identity and preserves its food snapshot and intended timestamp. Schedule deletion retains previously generated events.

Final Stage 6.2–6.3 verification on 2026-09-15 covers the populated-store additive upgrade, persistence round trip, bounded catch-up, deterministic two-context deduplication, schedule deletion, occurrence skip, concurrent skip/edit, series-history deletion, and concurrent series-delete/edit behavior. The full unit suite passed **119 tests with 0 failures**; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.15_19-02-35--0700.xcresult`. The full UI suite passed **23 tests with 0 failures**, including reminder row editing, occurrence/series deletion, schedule creation, relaunch, and generated-event visibility; result `DerivedData/Logs/Test/Test-PetTrackerApp-2026.09.15_18-48-29--0700.xcresult`.

## Stage 6.4: Functionality-Tweak Milestone Verification - Planned

Goal: validate the three functionality stages together before release-readiness work.

Tasks:
- Run the app/test build and full unit suite after each stage; run focused UI tests for the changed workflow before moving on.
- At milestone completion, run the full UI suite and a two-context sync regression covering archive/restore, reminder occurrence deletion, series deletion, and scheduled-event deduplication.
- Verify on the physical iPhone that existing personal data survives the model upgrade and that local notifications are rescheduled correctly.
- Update `design.md`, `handoff.md`, and user-facing developer notes to reflect final implemented behavior and any scope changes.

Acceptance checks:
- Existing populated local and CloudKit data upgrades without reset/reseed or loss.
- All new actions persist across relaunch and converge across sync contexts.
- Full unit/UI regressions pass before Stage 7 begins.

## Stage 7: Polish, Testing, and Release Readiness
Goal: make v1 reliable enough for personal daily use.

Tasks:
- Add focused unit tests:
    - payload validation
    - calorie calculation
    - multi-event creation
    - reminder recurrence
    - day-only overdue behavior
- Add UI smoke tests for main flows if practical.
- Improve empty/loading/error states.
- Review accessibility:
    - dynamic type
    - VoiceOver labels
    - sufficient touch targets
- Review mobile ergonomics:
    - fast food entry
    - fast litter logging
    - medicine completion from notification/homepage
- Add lightweight developer documentation:
    - how to run the app
    - architecture overview
    - where to add a new event type later

Acceptance checks:
- Core workflows are usable from a fresh install.
- Tests cover the behavior most likely to regress.
- App works at common mobile viewport sizes and with larger text.
- Architecture still has a clear path for v2 features.

## Future-Version Design Hooks
These should not be built in v1 unless they become unexpectedly cheap, but v1 should avoid blocking them.

- Household sharing through iCloud permissions.
- Widgets for viewing notifications and marking reminders done.
- User-added event types.
- Saved multi-event templates, such as "Dinner" creating multiple food events and being notified as one thing.
- Smart litter box data as a separate poop/weight event type, not the same as litter cleaning.
- Standard/metric conversion.
- Additional settings:
    - homepage lookahead window
    - preferred pet order
    - calorie display preferences
    - data export
- Other pet apps:
    - deep links to outside apps
    - data import
- Other pet types, starting with dogs if needed.

## Suggested First Milestone
The first useful milestone should be:

- SwiftUI app shell
- local sample data
- read-only homepage
- read-only food event list
- pet page with calorie totals
- simple architecture in place

This gives a visible app quickly while validating the hardest display rules before persistence, sync, and notifications add complexity.

## Home interaction follow-up — Complete (2026-11-22)

Requested after the user updated the physical iPhone and confirmed its saved data remained intact.

- Home care/health events and reminders expose Edit/Delete on left swipe. Event deletion is confirmed; recurring reminder deletion retains occurrence/series choices through a shared confirmation with the Reminders tab.
- Home event taps no longer navigate. Editors are opened through swipe actions.
- Right swipe on Home reminders exposes Skip Instance, reusing the existing synced occurrence-skip path. Recurring reminders advance; one-offs are removed. Neither logs a care event or completion history.
- Recent shows all care and health entries in the past 24 hours, extending to the latest 10 when needed, newest first with local-day headings. Future timestamps are excluded; category collapsing is removed.
- Health deletion goes through repository transactions and sync tombstones. No database schema changes or data reset.

Verification:
- App/test build passed on the iPhone 17 simulator.
- Full unit/persistence/sync suite: **123 tests passed**, including 24-hour boundary, more-than-10 entries, older-history fallback, mixed care/health ordering, day grouping, health deletion persistence/failure, and deletion sync/replay.
- Four focused UI workflows passed across runs: Home care-event tap/edit/delete/cancel/relaunch; Home reminder edit/skip/delete/relaunch; Health creation/Home swipe editing/deletion/pet timeline/persistence; existing Home Complete Now.
- Initial UI failures were a missed initial Health tap (passed on rerun), an incorrect test expectation that a skipped reminder beyond Home's Due window would remain visible, and an ambiguous XCTest confirmation-button selector. The expectation/selector were corrected and the affected tests passed. The full UI suite and physical-device verification were not rerun for this follow-up.
- Result bundles under `/Users/tammie/Library/Developer/XcodeBuildMCP/workspaces/PetTrackerApp-8636fea96c6a/result-bundles/`:
  - `test_sim_2026-11-22T19-39-40-635Z_pid82668_f688fe25.xcresult`: passing Home care-event workflow (initial run also contains the documented UI failures).
  - `test_sim_2026-11-22T19-42-18-724Z_pid82668_b5c22d0b.xcresult`: all 123 unit tests and Health workflow passed (reminder selector failed before correction).
  - `test_sim_2026-11-22T19-44-59-307Z_pid82668_89d052ee.xcresult`: both Home reminder workflow and Complete Now passed, zero failures.
- `git diff --check` passed. Changes are not committed yet; the pre-existing untracked shared Xcode scheme was preserved.

## November 22, 2026: Events, Reminders, and Notifications refinement

- [x] Move Events + beside the category subheading; add an initially collapsed Recurring section above the log.
- [x] Create automatic food and litter schedules through Recurring on event add; repeat and end-date controls expand when enabled. Medicine remains manual/reminder-completed.
- [x] Keep Reminders + in the heading bar and exclusively for reminders. Remove Mode; optional Create Events entries support multiple types, pets, and payload snapshots.
- [x] Preserve atomic medication-warning behavior for combined completion and deterministic sync for every action, partial pet completion, household entries, and replayed deletion.
- [x] Open a single Notifications page from Settings; daily reminder time first, followed by Food/Medicine/Litter overrides. Use default starts selected and clears on option changes. Remove global presentation controls handled in iPhone Settings.
- [x] Keep legacy reminders and food schedules readable; add optional SwiftData fields and explicit sync envelope version 2 for the new payloads.
- [x] Build and pass 131 unit tests, including upgrade of a copied pre-change public test database without reset.
- [x] Complete screen-flow regression verification and record results below.

The Stage 5 settings and Stage 6.3 Reminders-tab schedule UI descriptions above are historical; this refinement supersedes those screen locations and expands automatic schedules to litter.

Verification evidence (iPhone 17 simulator, iOS 26.5; isolated public test store):

- Full unit rerun: 131 passed, including pre-upgrade database preservation and litter-only action persistence. `test_sim_2026-11-22T20-33-25-924Z_pid82668_01be95f8.xcresult` also passes the mixed food/medicine reminder UI flow.
- Initial 26-test UI run passed 23. Remaining issues were a narrow menu hit target, scrolling to virtualized form fields, and a real collection-view crash when a destructive swipe animation removed a reminder that was only being skipped.
- Confirmation-opening swipe buttons now use red tint without a destructive role; the alert performs the actual deletion. Keyboard dismissal, scrolling tests, and Add event hit area are corrected.
- Focused rerun passes all four tests: Home reminder edit/skip/delete, recurring litter create/delete with retained history, plain reminder create/edit/cancel/relaunch/skip/delete, and recurring food create/relaunch/edit. `test_sim_2026-11-22T20-37-31-648Z_pid82668_0f6d9bb3.xcresult`.
- Reviewed screenshots of Notifications defaults/overrides, the mixed-event reminder form, and Events recurring section above its dated log. Added persistent Amount/Calories/Dose labels to the reminder form.

Result bundles are under `~/Library/Developer/XcodeBuildMCP/workspaces/PetTrackerApp-8636fea96c6a/result-bundles/`. No personal simulator store or physical phone data was reset during this work.

Final focused run passes mixed-event reminder creation/completion with labeled payload fields, Events deletion cancel/confirm/relaunch, and Home no-op tap/edit/delete: `test_sim_2026-11-22T20-40-47-372Z_pid82668_cd982611.xcresult`. All 26 UI workflows have passing results across the full run and focused reruns after fixes; 131 unit tests pass. Build and `git diff --check` pass.
