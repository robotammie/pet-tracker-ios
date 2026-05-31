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

## Stage 0: Project Foundation
Goal: create a clean iOS app skeleton that can grow without turning into a pile of view code.

Tasks:
- Create a new iOS app project.
- Use SwiftUI for the UI layer.
- Choose minimum supported iOS version after checking SwiftData/CloudKit tradeoffs.
- Establish app module folders, likely:
    - `App`
    - `Models`
    - `Persistence`
    - `Repositories`
    - `Services`
    - `Features`
    - `SharedUI`
    - `Tests`
- Add basic dependency boundaries:
    - Views call view models or feature stores.
    - View models call repositories/services.
    - Persistence details stay out of views.
- Add a small seed-data path for development previews and simulator testing.

Mobile concepts to explain while building:
- SwiftUI app lifecycle.
- Navigation stack basics.
- State ownership: `@State`, `@Binding`, `@Observable`/view models, and why persistence should not leak everywhere.

Acceptance checks:
- App launches in simulator.
- Main navigation shell exists.
- Project has a clear folder/module shape.
- Sample data can render without real persistence.

## Stage 1: Domain Model and Persistence Shape
Goal: define the core data model before building screens that depend on it.

Tasks:
- Define core entities:
    - `Pet`
    - `CareEvent`
    - `SavedEventOption`
    - `Reminder`
    - `UserSettings`
- Define enums:
    - event type: food, litter, medicine
    - food type: wet, dry, treat
    - food unit: cup, oz
    - reminder mode: pure reminder, reminder to event
    - recurrence type: every N hours/days/weeks/months, N times per day
    - due style: timestamp, day-only
    - notification presentation settings: banner, sound, badge
- Define typed payload structs for event data:
    - `FoodEventData`
    - `LitterEventData`
    - `MedicineEventData`
- Add validation/sanitization helpers for each payload type.
- Decide implementation path for persistence:
    - Option A: SwiftData first, with repository interfaces around it.
    - Option B: CloudKit-shaped models first, with local-only behavior during early development.
- Prefer whichever path keeps learning friction reasonable while preserving a future CloudKit route.

Mobile/data concepts to explain while building:
- Why mobile apps often separate domain models from storage models.
- Local persistence vs sync persistence.
- Why storing calculated calories on events is safer than recalculating old history.

Acceptance checks:
- Models compile.
- Payload validation quietly drops unsupported/wrongly typed data.
- Food calories are stored on event creation/update.
- Unit conversion is not attempted in v1.
- Tests cover calorie calculation, food validation, and reminder next-due calculation basics.

## Stage 2: Core Navigation and Read-Only Views
Goal: make the app navigable and useful with sample data before adding forms.

Tasks:
- Build primary navigation:
    - Home
    - Events by type
    - Pet detail
    - Notifications
    - Settings
- Build homepage sections:
    - due/upcoming notifications through now + 24 hours
    - most recent action per category
    - quick add buttons
- Build event list views:
    - food events grouped by day
    - medicine events grouped by day
    - litter recent action/history where useful, without a dedicated litter history page for v1
- Build pet detail:
    - pet-specific food and medicine events
    - global food events inside daily food groups with a global indicator
    - exclude global food from pet-specific calorie totals
    - exclude litter cleaning events

Mobile/UI concepts to explain while building:
- SwiftUI lists and sectioned data.
- Empty states.
- Why mobile views should optimize for quick repeated actions.

Acceptance checks:
- Sample data shows correctly on all main screens.
- Global food appears on pet pages but does not affect daily calorie totals.
- Litter cleaning does not appear on pet pages.
- Navigation works comfortably on mobile-sized simulator screens.

## Stage 3: Event Creation and Saved Autofill Options
Goal: support the core logging workflows.

Tasks:
- Build shared event creation flow shell:
    - event type selection
    - timestamp defaulted to now
    - editable timestamp
    - optional saved autofill selection
    - save/update saved option checkbox when edited/new data appears
- Build food creation:
    - no pet, one pet, or global event
    - saved food dropdown/new option
    - amount input
    - locked unit from saved food
    - live calorie calculation
    - multi-pet same-food/time creation
    - ignore blank/zero amounts in multi-pet creation
- Build medicine creation:
    - pet required
    - saved medicine dropdown/new option
    - dosage/unit required
    - multiple pets with per-pet dose, creating one event per pet
    - option to autoqueue notifications when creating saved medicine data
- Build litter creation:
    - one-tap/global cleaning event
    - no pet selection
- Build saved option management:
    - list saved options by event type
    - add/edit options
    - soft delete options

Mobile/UI concepts to explain while building:
- Form design on iOS.
- Pickers vs menus vs sheets.
- Input validation that helps without nagging.

Acceptance checks:
- Events can be created for all v1 event types.
- Saved autofill options are scoped per event type.
- Multi-pet food creation creates one event per cat with a nonzero amount.
- Medicine multiple-pet creation creates one event per selected pet.
- Soft-deleted saved options stop appearing in creation forms.

## Stage 4: Reminder and Notification Logic
Goal: get reminder behavior correct before worrying about final notification polish.

Tasks:
- Implement reminder model and scheduling service.
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
