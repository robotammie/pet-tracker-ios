# Pet Tracker Handoff

Use this file to resume the project in a fresh Codex chat/session.

## Resume Prompt

```text
We are continuing an iOS SwiftUI app in this repo. Please read README.md, design.md, plan.md, and handoff.md, then inspect git status before making changes. Stages 5.5–5.9 are committed; preserve the completed work. Stages 5.7–5.8 were authorized with testing between stages; both are complete and verified. Read plan.md for results. Stage 5.9 is complete and verified (option A, four categories, Health Quick Add/Recent, lb default); final build, 68 unit tests, and all 14 UI tests passed; read plan.md for results. Stage 5.10 is complete and committed: final build, 83 unit tests, and all 21 UI tests passed. Read its implementation notes in plan.md; do not start Stage 6 until requested.
```

## Project Snapshot

- App: native iOS SwiftUI pet care tracker.
- Current milestone: Stages 0 through 5.10 are complete and verified. Changes are committed as requested.
- Persistence: SwiftData for app data, UserDefaults for device-local notification settings.
- Sync: CloudKit is planned for Stage 6, after local polish.
- Scope: cats/pets, food events, medicine events, litter events, health history, reminders, saved food/medicine options, local notifications, focused settings.
- Out of v1 scope: photos, Android, custom event types, widgets, household sharing, and unit conversion.

## Completed Capabilities

- SwiftUI tab app with Home, Events, Pets, Reminders, and Settings.
- Local SwiftData persistence with repository boundaries.
- First-launch sample seeding from `SeedData.local.swift` when present, otherwise public seed data.
- Quick-add food, medicine, and litter flows.
- Multi-pet food and medicine creation.
- Saved food and medicine option management.
- Medicine reminder autoqueue, recurrence logic, completion, ignore-until, mute, delete, and completed history.
- Stage 5.10 adds verified pet name/calorie-goal editing, general reminder creation/editing, Events +/confirmed deletion, and inline food/medication option creation.
- Reminder-to-event completion that can log care events.
- Local notification scheduling with global and per-event-type presentation settings.
- Badge count support for overdue active reminders.
- Debug-only Settings > Development > Reset and Reseed Local Data.

## Completed Stage 5.5 Work

Stage 5.5 goal: local polish before CloudKit.

Completed Stage 5.5 work:

- Keep README and plan aligned with actual app behavior.
- Add small UI smoke tests.
- Add/refine accessibility identifiers needed by UI tests.
- Review empty states, first-run state, touch targets, and Dynamic Type.
- Document simulator and real-device reset/reseed workflow clearly.
- Keep unit-test workflows fast and avoid accidentally making every local test run launch UI automation.

Stage 5.5 changes:

- UI target and seven smoke tests for launch, food/medicine/litter logging, reminder completion, settings persistence, and debug reset confirmation.
- Debug-only UI test mode uses `UITests.store`, a separate settings suite, and public seed fixtures with empty event history. `-uiTestingReset` clears only test data; relaunches omit it to verify persistence. Notification scheduling is replaced with a no-op during UI tests.
- Accessibility identifiers on actionable controls and reminder rows; avoid identifiers on containers that propagate to children.
- Destination menu fills its row with a 44-point minimum touch area; amount and dose fields have 44-point minimum heights and pet-specific accessibility labels.
- Empty food/medicine option lists explain where to add options.
- Unit scripts explicitly select `PetTrackerAppTests`; `scripts/test-ui.sh` selects UI tests separately. Simulator name overrides now also drive the default destination.
- README documents reset/reseed on simulator/device, incompatible-schema reinstall, test isolation, and current pet/reminder editor limits.

Verification and final milestone status are recorded in `plan.md`. Changes are committed as requested.

## Plugin Status

The `build-ios-apps` skills are active in this session, and XcodeBuildMCP simulator, UI inspection, and debugging tools are available. Active skill location:

```text
/Users/tammie/.codex/plugins/cache/openai-curated-remote/build-ios-apps/0.1.2/skills
```

Use relevant SwiftUI skills for UI work and the debugger skill for simulator checks. The app remains compatible with iOS 17; Liquid Glass is optional future work and must not raise the minimum target implicitly.

## Testing Notes

Existing helper scripts:

- `scripts/build-for-testing.sh`: compile app and tests without launching simulator tests.
- `scripts/test-without-building.sh`: rerun unit tests only after a successful build.
- `scripts/test.sh`: build and run unit tests only.
- `scripts/test-ui.sh`: build and run the separate UI smoke suite.

Important simulator note:

- XCTest bodies are generally fast, but attaching to the iOS simulator test runner can take 60-90 seconds and may look quiet.
- CoreSimulator access may require an escalated command approval in Codex.

Recent known result before Stage 5.5:

- Stage 5 verification: `scripts/build-for-testing.sh` and `scripts/test-without-building.sh`, 38 tests passed.

Stage 5.5 verification completed on 2026-09-13: build passed, 38 unit tests passed, and the final full UI smoke suite passed all 7 tests. See `plan.md` for review details.

## Local Seed Data

Private seed data lives in:

```text
PetTrackerApp/Services/SeedData.local.swift
```

That file is git-ignored. Cloners should copy the public example:

```sh
cp PetTrackerApp/Services/SeedData.local.example.swift \
  PetTrackerApp/Services/SeedData.local.swift
```

Then edit the local seed data file before first run or before using the debug reset/reseed workflow.

## Git Notes

Always inspect status before changing files:

```sh
git status --short
```

Do not revert unrelated user changes. The user requested committing Stage 5.5–5.9 after updating litter icons to `tray`. Preserve the completed work.

## Stage 5.6 Design Updates

Stage 5.6 is complete: build passed, 44 unit tests passed, and all 8 UI smoke tests passed on 2026-09-13.

Implemented small requested changes:
- Complete now checkmark buttons on Home Due and Reminders Active. Completion time is now, all remaining pet targets are completed, reminder-to-event payloads are logged, and pure reminders create no event. The older swipe completion flow remains available.
- Events filter by All pets (including Household), Household, or an individual pet's own events.
- Wet food supports fractional cans and calories per whole can.
- Saved food options have an optional official name; saved medicine options have optional type/purpose text. Event display names and historical payloads are unchanged.
- Existing medication cadence survives saved-option metadata edits.

The user authorized 5.7 past-event editing and 5.8 same-medication/same-cat dose interval warnings (with override); 5.9 is complete and verified. The approved design is `health-design-options.md`. The user chose same-medication/same-cat dose checks and dismissed different-medication interaction work entirely.

## Next Suggested Move

Stage 5.9 is complete and committed. Stage 5.10 is complete and committed: final build, 83 unit tests, and all 21 UI tests passed. Stage 6 can begin when requested. The user approved Health inside pet detail, weight/visits/procedures/general notes, Health last in Quick Add and included in Recent, and lb as the default weight unit. Do not enable CloudKit until the agreed pre-sync changes are settled. Changes are committed as requested.


## Stage 5.7–5.8 implementation notes

- `Features/Events/CareEventEditDraft.swift` and `CareEventEditorView.swift`: typed historical editor; preserves event ID/createdAt and payload snapshots. Explicit food calorie recalculation uses only the original stored rate for its unit. Unit/manual calorie changes invalidate that rate.
- `Services/MedicationTimingService.swift`: medication identity resolution, nearest-neighbor and batch checks, next prescribed window. The configured minimum controls early warnings; maximum defines the displayed window.
- `SharedUI/MedicationDoseIntervalFields.swift`: saved-option global and pet-specific prescribed hours. No automatic interval defaults.
- `SharedUI/MedicationTimingAlert.swift`: warning presentation is scoped to root, medicine creation, event editor, or reminder completion so sheets display their own alert.
- `Repositories/PetCareStore.swift`: central deferred write gate. Cancel makes no changes; Log anyway acknowledges warning text/time for each affected event. Pending writes clear before commit, preventing duplicate confirmation; changed history/prescription requires fresh acknowledgement. Stale reminder snapshots cannot commit.
- New medicine event/target payloads carry saved-option ID and interval snapshot. Unique trimmed/case-insensitive legacy names resolve only against exactly one saved medication (including deleted ones); ambiguous identities require acknowledgement. Resolved historical payloads are not automatically persisted until saved as a candidate.
- SwiftData additions are optional scalar fields plus optional JSON for pet intervals. Existing domain payloads decode without identity/timing. Checks use a matching option's current interval, otherwise a linked snapshot; no configured interval means unchecked timing.
- Stage 5.7 verified first: 48 unit tests and focused edit/relaunch/cancel UI test passed. Stage 5.8 final build passed, all 61 unit tests passed, and all 13 UI tests passed (366 seconds). Logs: `/tmp/pettracker-58-build-final.log`, `/tmp/pettracker-58-unit-verified.log`, `/tmp/pettracker-58-ui-verified.log`; detailed results are in plan.md.
- Different-medication interactions are removed from scope. Stage 5.9 Health is complete and verified.


## Stage 5.9 implementation notes

- `Models/HealthModels.swift`: separate HealthEntry, typed weight, four categories, lb/kg units, edit draft, and recent-health grouping. Weight defaults to lb and retains its entered unit.
- `Persistence/HealthPersistence.swift`: SwiftData HealthEntryRecord, mapping, and throwing repository saves. The App schema and both debug reset paths include health records.
- `Features/Health/HealthEntryEditorView.swift`: required-pet add/edit form, title/date/notes and optional clinic/provider, positive finite weight, Save/Cancel, and save errors that keep the editor open.
- `Features/Health/HealthTimelineView.swift`: pet-specific newest-first/day-grouped history, category filter, empty state, Add, and tap-to-edit rows.
- Pet detail has Care / Health; Recent links initialize Health while preserving subsequent local picker choices. Home Quick Add ends with Health; Recent merges care/health by time and keeps latest-per-pet/category entries over seven days, excluding future timestamps.
- No initial health seed entries. Pet-detail Add preselects the pet; Home Add requires an explicit choice. Health records leave care calories and reminders independent.
- Follow-up reminders, charts, attachments, custom categories, and integrations remain deferred. No interaction work is planned.
- Stage 5.9 final app/test build passed, all 68 unit tests passed, and all 14 UI tests passed (472 seconds). Logs: `/tmp/pettracker-59-build-final.log`, `/tmp/pettracker-59-unit-verified.log`, `/tmp/pettracker-59-ui-final.log`. Health UI covers Quick Add, lb default, Recent links, editing, relaunch, category filtering, Cancel, and pet isolation. Initial test-helper issues were fixed; the final full suite is green. See plan.md for result bundles.

## Final icon update and commit

The user requested litter icons use SF Symbol `tray` throughout Home/Recent, reminders, litter creation, saved options, and Settings. This icon-only update follows the passing Stage 5.9 build, 68 unit tests, and 14 UI tests. Stages 5.5–5.9 and documentation are included in the requested commit.

## Stage 5.10 completion notes

The user reviewed the original-design gaps one by one and approved minimal pet add/edit, general reminder creation/editing, Events + creation, confirmed care-event swipe deletion, and inline Add new food/medication with automatic selection. Complete and verify these before Stage 6. Pet deletion and the broader saved-option save/update checkbox behavior are deferred. See plan.md for scope and acceptance checks. Implementation is complete and verified: final build, 83 unit tests, and all 21 UI tests passed. Logs and result bundles are in plan.md. The requested implementation commit includes these documentation updates.


- Pet editor preserves IDs; detail reads the current stored pet so edited names/goals update immediately. Name is required and the optional goal must be a positive integer.
- ReminderEditDraft/ReminderEditorView support interval and editable times-per-day schedules, end dates, pure/event-linked modes, and household/per-pet payloads. Partially completed occurrences retain completed targets and lock scope/mode/type; only active definitions can be edited. Stale drafts ask to reopen rather than overwriting changed state. Clearing an option restores recorded details while editing or requires choosing a payload for a new reminder.
- Events + reuses EventCreationSheet; confirmed deletion refreshes the store without changing reminder history. Inline saved-option creation uses its own cancelable sheet and selects the saved result. New medication selection applies its default dose/unit; new food preserves entered amounts and uses the selected unit/rate. Full-row Add new touch targets prevent missed taps.
- Private seed data and the separate personal simulator remain outside UI-test workflows. CloudKit remains unstarted.
