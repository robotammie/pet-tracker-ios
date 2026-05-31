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

#### event type details

##### Food
Saved food fields:
- `name`: string
- `unit`: enum, `cup` or `oz`
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
- `dosage`: float
- `unit`: string
- `cadence`: recurrence-like value, exact storage format TBD.
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
- Include an ignore option.
    - Ignore until: updates the next due date to a selected date/time.
- Recurring notifications should calculate the next due date from the completion time, not from the originally scheduled due time.
- When completing a notification, the user may edit the completion time.
    - This supports cases where the user did the task earlier and is logging it later.
    - If the notification recurs, the edited completion time is used to calculate the next due date.

### user settings
Initial settings should stay small and focused.

Notification preferences:
- Global notification presentation preference.
    - Banner, sound, and badge controls should be available in-app for finer granularity.
    - iOS system settings may still override app-level notification preferences.
- Optional per-event-type notification preferences.
    - Example: medicine reminders may be more intrusive than litter reminders.
    - Banner, sound, and badge preferences may vary by event type.
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
