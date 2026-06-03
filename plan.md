# Pet Tracker Build Plan

This plan assumes the current direction in `design.md`: iOS native, SwiftUI-first, local/iCloud-owned data only, good architecture from the beginning, and enough explanation along the way for a developer new to mobile app work.

## Current Clarification Status
No blocking product clarifications are needed before starting the app plan.

Known choices:
- Build iOS native only for v1.
- Prefer SwiftUI.
- Design the data layer so CloudKit/iCloud sync can be supported without rewriting the UI.
- Treat food, litter, medicine, notifications, saved autofill options, pets, and settings as separate model concerns.
- Keep v1 settings focused on notification preferences and the global day-only notification time.

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
- Home screen now has no-op quick add controls and collapsible Due/Recent sections.
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

## Stage 3: Event Creation and Saved Autofill Options
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
- Build shared event creation flow shell:
    - event type selection
    - timestamp defaulted to now
    - editable timestamp
    - optional saved autofill selection
    - save/update saved option checkbox when edited/new data appears
- Build food creation:
    - household, one-pet, or multi-pet mode in one form
    - saved food dropdown/new option
    - amount input for household/one-pet mode
    - per-pet amount input for multi-pet mode
    - locked unit from saved food
    - locked calories-per-unit from saved food
    - live calorie calculation from amount x calories-per-unit
    - allow amounts like 2 cans/units for a single logged event
    - multi-pet same-food/time creation
    - ignore blank/zero amounts in multi-pet creation
- Build medicine creation:
    - pet required
    - saved medicine dropdown/new option
    - dosage/unit required
    - multiple pets with per-pet dose, creating one event per pet
- Build litter creation:
    - one-tap/global cleaning event
    - no pet selection
    - timestamp editable
- Build saved option management:
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

## Stage 4: Reminder and Notification Logic
Goal: get reminder behavior correct before worrying about final notification polish.

Tasks:
- Implement reminder model and scheduling service.
- Add option to autoqueue notifications/reminders when creating saved medicine data.
- Support pure reminder vs reminder-to-event.
- Support recurrence:
    - every N hours
    - every N days
    - every N weeks
    - every N months
    - N times per day with suggested editable default times
- Support timestamp vs day-only due style.
- Use global default day-only display time, defaulting to 9:00 AM.
- Keep overdue reminders visible until completed, ignored, or deleted.
- Add ignore-until behavior.
- Add completion flow:
    - completion time defaults to now
    - user may edit completion time
    - recurring next due time is based on completion time
    - reminder-to-event completion can create/log the event
- Support optional schedule end date.
- Stop medicine reminders automatically at schedule end date.

Mobile concepts to explain while building:
- Local notifications on iOS.
- App-level preferences vs iOS system notification settings.
- Why scheduling and visible reminder state are related but not identical.

Acceptance checks:
- Reminder next-due tests cover normal, late, and edited-completion cases.
- Day-only reminders show starting at configured morning time and become overdue after midnight.
- Ignored reminders update due date and leave history intact as needed.
- Reminder-to-event completion creates the expected care event.

## Stage 5: Settings
Goal: expose the small set of v1 settings without turning settings into a junk drawer.

Tasks:
- Build settings view.
- Add global notification presentation preferences:
    - banner
    - sound
    - badge
- Add optional per-event-type notification presentation preferences.
- Add global default day-only notification time.
- Make reminder scheduling read from these settings.
- Make clear in implementation notes that iOS system settings can override app-level notification behavior.

Mobile concepts to explain while building:
- UserDefaults vs persisted app data.
- Which settings belong locally vs in iCloud.
- iOS notification permission and presentation constraints.

Acceptance checks:
- Settings persist across app launches.
- Default daily notification time affects new day-only reminders.
- Per-event-type presentation preferences override global preferences where set.

## Stage 6: iCloud/CloudKit Sync
Goal: connect persistence to iCloud once local behavior is stable.

Tasks:
- Enable iCloud/CloudKit entitlements.
- Map local persistence models to CloudKit-compatible records or SwiftData CloudKit configuration.
- Validate sync behavior for:
    - pets
    - events
    - saved options
    - reminders
    - settings that should sync
- Decide which settings should stay device-local.
    - Notification presentation preferences may be device-local because notification behavior can differ by device.
- Handle iCloud unavailable/signed-out state gracefully.
- Add basic conflict expectations.

Mobile/sync concepts to explain while building:
- CloudKit containers and entitlements.
- Offline-first behavior.
- Sync conflicts and why timestamps/IDs matter.

Acceptance checks:
- Data persists locally.
- Data syncs between two simulator/device contexts where feasible.
- App remains usable when iCloud is unavailable.
- No server-side app state is introduced.

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
