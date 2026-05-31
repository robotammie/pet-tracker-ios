# Pet Tracker

Pet Tracker is a personal iOS app for tracking cat care events, reminders, saved autofill data, and notification-driven care routines.

The app is currently in the planning/design stage.

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
- Persistence: architecture should support CloudKit/iCloud sync without forcing UI rewrites.
- Data layer: keep persistence behind repository/service boundaries.
- Notifications: use iOS local notification APIs, with app-level preferences where possible and system settings respected as overrides.

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

## Suggested First Milestone

Build a SwiftUI shell with local sample data, a read-only homepage, a read-only food event list, and a pet page with calorie totals. This validates the hardest display rules before persistence, sync, and notifications add more moving parts.
