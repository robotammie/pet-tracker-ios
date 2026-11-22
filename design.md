# Pet Tracker Design and Requirements

## Problem
I want one place to hold data for caring for my cats. App is primarily for personal use.
Developer has coding experience, but has never built a mobile app before, so explanations of mobile-specific design and implementation tradeoffs will be necessary.

## Technical Direction
- Platform: iOS native only.
- Development style: prioritize good architecture from the beginning, even for v1.
- Learning style: include explanations, pros/cons, and multiple options when choices are meaningful.
- Data ownership: all data must be stored locally and/or in the user's iCloud. There must be no app server-side state.

### iOS native implementation options
#### SwiftUI
Pros:
- Apple's current recommended declarative UI framework.
- Good fit for mobile-first screens, forms, lists, navigation, and state-driven UI.
- Integrates well with SwiftData, CloudKit, local notifications, widgets, and other Apple frameworks.
- Usually less boilerplate than UIKit for new apps.

Cons:
- Some advanced layouts and custom interactions can be harder to reason about while learning.
- Framework behavior can feel "magic" until the state/data-flow model clicks.
- Newer APIs may require choosing a minimum iOS version carefully.

#### UIKit
Pros:
- Mature, very explicit, and heavily documented.
- More examples exist for older patterns and edge cases.
- Gives detailed control over navigation, layout, and lifecycle.

Cons:
- More boilerplate for a new app.
- Less ergonomic for simple form/list-heavy apps than SwiftUI.
- Apple's newer sample code and APIs increasingly assume SwiftUI.

#### Recommended v1 direction
Use SwiftUI unless a specific requirement appears that strongly favors UIKit. This app is mostly lists, forms, detail views, notifications, and persistent data, which is a strong match for SwiftUI.

### Storage and sync options
#### Local-only storage
Pros:
- Simplest to build, test, and debug.
- No iCloud account, entitlement, sync conflict, or offline-sync behavior to manage.
- Good for the fastest first prototype.

Cons:
- Data does not automatically sync across the user's devices.
- Backup/restore behavior depends on device backups and app container handling.
- Adding sync later may require migration work.

#### CloudKit/iCloud sync
Pros:
- Keeps data in Apple's ecosystem without running an app server.
- Can sync across the user's own Apple devices.
- Supports future sharing features better than local-only storage.
- Aligns with the hard requirement that data stay local/iCloud.

Cons:
- More setup: iCloud entitlements, containers, schema, permissions, and device testing.
- Sync bugs are harder to reproduce than local persistence bugs.
- Conflict handling and offline behavior need deliberate design.
- App behavior depends on the user being signed into iCloud and allowing iCloud Drive/app data.

#### Recommended v1 direction
Prefer an architecture that can support CloudKit from the beginning. If implementation risk is high, build the data layer behind a repository/service interface so local persistence can come first and CloudKit sync can be added without rewriting the UI.

## Requirements
- [hard] All data must be stored either locally or in the user's iCloud. No app server-side state.
- [hard] iOS native only for v1.
- User may store pet care events (eg feeding, cleaning litter)
- User may set notification alerts (eg clean fountain, empty litter)
- User may save event data (food type, etc) for autofill in later event creation
- Saved event data/autofill options are shared per event type.
- code should aim for building reusable modules/helpers rather than hard-coding everything
- should also be human readable and maintainable
- UI should be optimized for mobile viewing/use
- Photos are not required for v1.

## Current implementation boundary (reviewed 2026-09-15)

Stages 0–5.10 are complete; the final build, 83 unit tests, and 21 UI tests passed. Litter icons now use `tray`. The pre-CloudKit updates below take precedence over older descriptions when they differ.

Original-design capabilities completed in Stage 5.10:
- Pet add/edit name and optional calorie-goal UI; edits preserve the pet ID and linked history.
- General reminder creation/editing UI with due style, recurrence/end date, and applicable targets; saved medicine creation can still autoqueue a daily reminder. Completed targets and history are preserved.
- Events + routes to the selected type. Inline Add new food/medication opens saved-option creation and selects the saved result; Cancel preserves the prior selection. The broader save/update checkbox is deferred. Saved food unit/calorie rate are locked during creation, as explicitly selected in Stage 3; historical editing is available.
- Confirmed care-event swipe deletion updates history and calorie totals without changing reminder completion history. Health add/edit is complete; health deletion was not part of the approved initial scope.

The user approved completing all five gaps before sync as Stage 5.10: minimal pet name/calorie-goal add/edit; general reminder creation/editing with preserved completed history; Events + routed to the selected type; confirmed care-event swipe deletion without changing reminder history; and inline Add new food/medication using the existing editor and selecting the result. Pet deletion and the broader save/update checkbox behavior remain deferred. Food units/calorie rates stay locked during logging. These decisions are implemented and verified. The older statement that litter has no history page means no separate litter-only screen: the shared Events tab includes litter history, as implemented in Stage 2.

Step 6 must include Health records, preserve existing local history, prevent duplicate initial seed data across devices, refresh the feature store after imported changes, and reconcile reminder completion/history without duplicate logged events. Schema compatibility and iCloud setup are Step 6 work, not proof that sync can be enabled immediately. All current notification settings remain device-local.

Sync execution update (2026-09-15): the developer account, signing team, app identifier, and Development CloudKit container are configured. Future multi-user/household sharing remains a product goal. Stable identities and account/database/record ownership remain behind repository/sync boundaries; sharing UI, invitations, and permissions remain future work. Data stays local and/or in users' iCloud, without app server-side state.

Stage 6 implementation: explicit CloudKit transport over local SwiftData, a durable offline journal with tombstones, deterministic completion reconciliation, and account/container/environment/zone scope boundaries. Signed Debug builds use the Development container; Release remains local-only until its schema is deployed. All app data, including Health and automatic food schedules, is mapped; notification preferences remain device-local. Foreground/import/account-change refresh and local notification rescheduling are implemented. No background push or sharing UI is included. See [sync-design.md](sync-design.md) for conflicts, durability, provisioning, live verification, and the future household-sharing path.

Stages 6.2–6.3 add direct active-reminder editing, confirmed recurrence deletion, and food-only automatic event schedules. Delete This Occurrence advances from the scheduled due time without completion history or a care event. Delete All removes the active series and its completed reminder history while retaining logged care events. Automatic schedules are separate synced entities: they create deterministic food events at their intended timestamps when the app next runs, without reminders or notifications. Stage 6.1 event archive/restore/duplicate work remains planned.

## Data
### pet
name: str
cals_per_day: int, nullable
photo: optional, not required for v1

### event
Core fields shared by all event types:
- `type`: enum, v1 values:
    - `Food`
    - `Litter`
    - `Medicine`
- `pet`: fkey, nullable. Null means global/household event.
- `created_at`: timestamp, defaults to now.
- `start_time`: timestamp, defaults to now.
- `end_time`: timestamp, nullable.
- `data`: typed event payload stored as JSON/dictionary-like data.

Treats are included in `Food` for v1. There is no generic `Other` event type in v1.

#### event subtype validation
Each event subtype will have specific data allowed. Any data not in this allow list or of the wrong type should be quietly discarded prior to save.

#### saved event data / autofill options
Saved event data is scoped per event type. For example, saved food options should not appear in litter or medicine forms.
Saved autofill options are global across pets for v1.
Future versions may allow pet-specific saved options if that becomes useful.
Editing saved food or medicine data affects future event creation only. Existing events keep their stored event payload.

#### deletion behavior
- Events are hard-deleted in v1.
- Saved autofill options are soft-deleted so they stop appearing in forms without breaking old events.
- Notifications/reminders can be hard-deleted.
- Notifications/reminders can also be muted, allowing the user to keep the reminder definition for later use without it appearing as active/due.

#### event type details

##### Food
Saved food fields:
- `name`: string, the user-given display name used in pickers and event snapshots.
- `official_name`: optional string, the full product name shown in saved-option management.
- `unit`: enum, `cup` or `oz`; wet food also supports `can`.
- `calories_per_unit`: integer
- `food_type`: enum, `wet`, `dry`, or `treat`

Food event fields:
- `name`: string
- `food_type`: enum, copied from saved food when selected.
- `amount`: float
- `unit`: enum, copied from saved food when selected.
- `calories`: integer, calculated live when amount changes in the form.

Validation:
- Only `name` is required.
- Pet selection is optional.
- Global food events are allowed.

Display:
- Home page: pet/global indicator | time ago | name | calories
- Pet page:
    - Day header: Today/Yesterday/date | total calories eaten | daily calorie goal if set
    - Lines: time | food type | food name | amount + unit
- Global food events should be listed inside the daily food group on pet pages with a global/household indicator.
- Global food events should not be included in pet-specific daily calorie totals.

Calculation/storage behavior:
- `calories` should be stored as the calculated value on the event at creation/update time.
- Storing calories on the event preserves historical logs if the saved food option changes later.
- Calories can be whole numbers for v1.
- The unit from the saved food option locks the event unit in v1 because the app does not support unit conversions.

Creation behavior:
- Food events support single-event creation with no pet, one pet, or global scope.
- Food creation should also support multi-pet entry for the same food/time.
    - User selects one food type and timestamp.
    - User enters amounts per cat.
    - Blank or zero amounts are ignored and do not create explicit zero-amount records.
    - App saves one pet-specific food event per cat.
    - This allows each cat's daily calories to be calculated separately.
- One selected food per batch is enough for v1.

##### Litter
Litter event fields:
- None for v1.
- Litter cleaning events are global by default.
- Assume all litter boxes are cleaned at once in v1.

Validation:
- None.

Display:
- Time ago.
- Litter box cleaning events should not display on cat/pet pages.
- Litter cleaning should not have a dedicated event history page in v1.

Future litter-related work:
- Smart litter box integrations may eventually provide poop data by cat, weight, or similar signals.
- That data should likely be modeled as a separate event type from litter box cleaning.
- This is a later goal, roughly v4, and should not affect v1 cleaning event design beyond avoiding assumptions that would block it.

##### Medicine
Saved medicine fields:
- `name`: string
- `purpose`: optional free-text string, such as antibiotic or painkiller.
- `dosage`: float
- `unit`: string
- `cadence`: optional `MedicineCadence` wrapping `RecurrenceRule`; persisted as recurrence kind/value/unit and times-of-day minutes.
    - v1 needs both every N hours and N times per day.
    - For N times per day, app should suggest default times that the user can edit.
    - v2 may need custom schedules, such as "1 per day for 5 days, then 1 every other day for 6 days."

Medicine event fields:
- `name`: string
- `dosage`: float
- `unit`: string, copied from saved medicine when selected.

Validation:
- Pet selection is required.
- Dosage is required.
- Unit is required.

Display:
- Pet | time ago | medicine name | dosage + unit

Form behavior:
- When creating new saved medicine data, allow an option to autoqueue notifications.
- User may select multiple pets, in which case individual doses can be set for each and one event is created per pet.
- Medicine reminder end dates belong to the notification schedule, not the saved medicine definition.
- Medicine reminders should stop automatically at the notification schedule end date.

### notification
include relevant event info so it can autolog an event when marked complete.

- Notification mode:
    - Pure reminder: completing/ignoring/deleting affects only the reminder.
    - Reminder to event: completing the reminder can create/log the associated event.
- Recurrence options:
    - Every N hours
    - Every N days
    - Every N weeks
    - Every N months
- Schedules may optionally have an end date.
- If a recurring schedule has an end date, notifications stop automatically after that end date.
- Notification due style:
    - Timestamp: notification has a specific due date/time and is overdue after that timestamp.
    - Day-only: notification is due sometime on a date, starts showing in the morning, and is not overdue until midnight at the end of that day.
- Day-only notification morning display time should default to 9:00 AM.
- Day-only morning display time should be customizable.
- Overdue notifications stay visible until completed, ignored, or deleted.
- Selecting an active reminder opens its editor; completed reminder history stays read-only.
- Deleting a recurring reminder requires choosing between skipping the displayed occurrence and deleting the whole series. Skipping advances from the displayed due time. Deleting the series also removes its completed reminder history, while care events already logged from it remain.
- Include an ignore option.
    - Ignore until: updates the next due date to a selected date/time.
- Include a mute status.
    - Muted notifications are kept for later use but should not appear as active/due.
- Recurring notifications should calculate the next due date from the completion time, not from the originally scheduled due time.
- When completing a notification, the user may edit the completion time.
    - This supports cases where the user did the task earlier and is logging it later.
    - If the notification recurs, the edited completion time is used to calculate the next due date.

### automatic scheduled event
- A scheduled event is separate from a notification and has no alert, completion, ignore, mute, or reminder history.
- The initial scope is saved food for automatic-feeder use, with household or one-pet scope, recurrence, and an optional end date.
- iOS does not guarantee app execution at an exact minute. Due occurrences are created on launch, foreground refresh, successful sync, and schedule saves; the care event keeps the intended scheduled timestamp.
- Occurrence IDs derive from schedule ID and scheduled timestamp so retries and multiple devices converge without duplicate events.
- Editing affects future occurrences. Deleting stops future creation and retains previously created care events.

### user settings
Initial settings should stay small and focused.

Notification preferences:
- Global notification presentation preference.
    - Banner, sound, and badge controls should be available in-app for finer granularity.
    - iOS system settings may still override app-level notification preferences.
    - Notification presentation preferences are per-device.
- Optional per-event-type notification preferences.
    - Example: medicine reminders may be more intrusive than litter reminders.
    - Banner, sound, and badge preferences may vary by event type.
    - Per-event-type notification presentation preferences are per-device.
- Default notification time for daily/day-only reminders.
    - Default: 9:00 AM.
    - User can customize.
    - Global only for v1; no per-event-type default daily time in v1.


## User View
- Homepage
    - Notifications: any user-set notifications that are due prior to now + 24 hrs, in due date order
        - done checkbox
            - for pure reminders, marks the reminder complete/reschedules if recurring
            - for reminder-to-event notifications, logs an event when completed
        - ignore button with "ignore until" date/time
        - new notification button
    - Most recent action per category (per pet, if relevant)
    - Button to view all events in a category
    - Button to add event to a category
- Events
    - per event type
    - include event data divided by day
        - today > 1 cup dry food 8 am, 2.5 oz wet 6pm, 1/2 c dry food 10pm
        - yesterday > ...
        - [date] > ...
    - new event of type button
- New Event
    - fields differ by event type 
    - time is autofilled to now, but can be changed (date/time type field)
    - Event Data:
        - Main field offers dropdown of saved options (eg Hills Dry Food) plus an option for 'new'
        - on selection of main field, additional fields will appear, pre-populated if a saved option is chosen
        - user may edit any fields
        - if any new data (either a new main field or edited subfields), user has a checkbox for save/update
            - if checked, data is added/updated
            - otherwise data is saved on that event but not persisted
-  View any saved event data autofill info (eg food options)
    -  can add new option w/ data
    -  can delete (soft delete on back end) options
- View pet
    - show events that pertain to specific pet
    - also show global events where no pet is specified
    - global events should have an icon or visual indicator denoting global/household scope
- Notifications
    - show all currently active notifications in time order, overdue first
    - notifications can be recurring (ie if every 2 weeks, will auto-redeploy at action marked done)
    - can be marked as done with the option to select done at time
    - can be ignored until a selected date/time
    - can be edited/deleted
    - includes a Scheduled Events section for adding, editing, and deleting food schedules
- Settings
    - notification preferences
    - default day-only notification time
    - optional per-event-type notification settings

## Future Work
Non-requirements that may become later features if feasible. Decisions that would make future work difficult should be highlighted and only made on purpose, not just because they are easier in the moment. If work is easy, can be looped in to current work.

- Sharing data to multiple members of the household.
    - would probably require some sharing permissions between users' iclouds.
    - indicate in form which user completed each action
- Widget - view notifications/mark as done from widget
- User-added event types
- Saved multi-event templates of the same type.
    - Example: "Dinner" creates multiple food events for different cats and can be notified as one thing.
    - Candidate for v2 depending on complexity.
    - V1 multi-pet food creation should be designed so this is not hard to add later.
- Additional settings.
    - Default homepage lookahead window for upcoming reminders.
    - Default pet or preferred pet order.
    - Calorie display preferences, such as showing/hiding daily calorie goal.
    - Data export.
- Standard/metric unit conversion.
    - V1 locks food units because there is no conversion support.
    - Later versions may support conversions between standard and metric units.
- Other pet apps (auto feeder manager, vet contact)
  - Provide link to open outside apps when reasonable
  - Import data from outside apps
- Support for other types of pet (dog first, possibly others later)

## Non-Goals
- Android support
    - If there's a best practice for making an app that ports easily to Android, we should do that, but main use case is personal
- Pet photos in v1


## Pre-CloudKit Updates (2026-09-13)

### Stage 5.6 implemented scope
- Home Due and Reminders Active rows have a checkmark Complete now control. It uses the tap time, completes all remaining targets, logs their stored payloads for reminder-to-event mode, and preserves recurring history/rescheduling rules. Pure reminders do not create events. The existing swipe Done flow remains for selected-pet or backdated completion.
- Events can be filtered by All pets (including Household), Household only, or one pet's own events. This filter is distinct from pet detail, which includes household food.
- Wet food can use fractional cans, with calories specified per whole can; no conversion between cans, ounces, and cups is attempted. Dry food and treats continue to use cups/ounces.
- Official food name and medication purpose are optional saved-option metadata. Existing event payloads keep their display names, doses, and stored calories. Changing metadata does not rewrite history.

### Stages 5.7–5.9 authorized
The user authorized 5.7–5.8 with testing between stages, then approved option A and the smaller Health & Life scope for 5.9.

**Past-event editing (Stage 5.7 implemented):** tap an Events row to edit date/time, scope, name, and subtype values. Preserve ID and createdAt; retain the event's historical snapshot rather than loading current saved-option values. Food supports amount/unit/calorie editing, medicine requires a pet and positive dose/unit, and litter remains household-only. Original events lack a calories-per-unit snapshot, so the editor must not silently recalculate old calories from the current food option. Add an optional rate snapshot for newly logged food; for older entries, let the user confirm/edit stored calories. Save through the existing repository upsert and refresh grouping/totals. Event edits do not rewrite reminder completion history or reschedule past reminders.

**Medication timing (Stage 5.8 implemented):** add structured minimum/maximum hours between doses (both 12 for a fixed interval; 8 and 12 for a range), with validation and a stable saved-medication ID on logged events/targets. Optional per-cat prescription overrides take precedence over the shared interval. The warning checks only the same medication and cat, as requested. Evaluate the proposed event timestamp, including backdated entries and neighboring doses when editing, excluding the edited event itself. Show prior dose, elapsed time, and the entered minimum interval; allow Cancel or Log anyway. Apply the check to manual logging, multi-pet logging, reminder completion, and Complete now before any writes. Batch warnings should identify affected pets and save once after confirmation. Store an override acknowledgement/reason with the event. No configured interval means no timing assertion; never label an unchecked dose safe. Legacy entries are resolved by trimmed, case-insensitive names only when exactly one saved medication matches, including deleted options. Resolution does not rewrite history automatically; newly saved events acquire the identity. Ambiguous candidates and nearby ambiguous historical doses require acknowledgement. A linked ID survives name edits. Checks use the current configured interval when its saved option exists, otherwise the linked interval snapshot. The maximum defines the displayed next-dose window; early warnings use the minimum. A disabled/unconfigured interval makes no timing check. Overrides store accepted warning text and acknowledgement time; editing does not erase prior acknowledgement metadata, which is shown as a recorded override rather than a safety status. Different-medication interactions are outside personal-use scope; no interaction work is planned.

Intervals should be entered from the veterinarian's prescription, not inferred from a medication's purpose. The FDA recommends asking the veterinarian how much and how often to give a pet's medicine: [Medications for Your Pet — Questions for Your Vet](https://www.fda.gov/animal-veterinary/animal-health-literacy/medications-your-pet-questions-your-vet).

**Health & Life (Stage 5.9 implemented):** Pets → pet detail uses a Care / Health picker. Health has typed weight, vet visits, procedures, and general notes, with required pet/title, happenedAt, immutable createdAt, updatedAt, notes, and optional clinic/provider. Weight is finite and positive, defaults to lb, and retains an explicit lb/kg unit without conversion. Date-grouped history supports category filtering, add with a preselected pet, and tap-to-edit. A separate HealthEntry repository and SwiftData record keep care calories and reminder history independent.

Home Quick Add ends with Health; its editor requires choosing a pet. Recent merges care and health chronologically, keeping the latest entry per pet/category over the last seven days, excluding future timestamps. A health Recent row opens its pet's Health view. Follow-up reminders, charts, attachments, imports, custom categories, and integrations are deferred. Medication interactions have been removed from scope at the user's request.

Detailed approved behavior and acceptance checks are in [health-design-options.md](health-design-options.md).

Stages 5.7–5.8 were verified in sequence: 5.7 passed 48 unit tests and its focused edit/relaunch/cancel UI test before 5.8 began. Final 5.8 verification passed the app/test build, 61 unit tests, and the full 13-test UI suite. Stage 5.9 passed the app/test build, 68 unit tests, and all 14 UI tests. See `plan.md` for logs and coverage.

Stage 5.10 completed the approved local gaps before CloudKit: pet name/calorie-goal add/edit with stable IDs; reminder creation/editing with recurrence/end dates, stored per-target payloads, and preserved completed history; Events +; confirmed event deletion; and inline saved-option creation/selection. Final build, 83 unit tests, and all 21 UI tests passed. No unanswered product decisions remain for the approved pre-sync scope.


Stage 6 live verification (2026-09-15): the signed app saved the populated phone dataset to the Development container. An isolated physical-device integration test used two independent local contexts and a temporary private zone to verify all synced categories, empty-context download, offline/reconnect, and concurrent partial reminder completion; it passed with no duplicate logical results and removed its test zone. The iPhone 17 simulator separately received a verified local copy of the phone dataset because that simulator's iCloud protected-key trust was unavailable.
