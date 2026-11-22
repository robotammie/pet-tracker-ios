# Pet Tracker Handoff

Use this file to resume the project in a fresh Codex chat/session.

## Resume Prompt

```text
We are continuing an iOS SwiftUI app in this repo. Please read README.md, design.md, plan.md, handoff.md, and sync-design.md, then inspect git status before making changes. Stages 0–6 and functionality Stages 6.2–6.3 are implemented; Stage 6.1 event history actions and Stage 6.4 milestone verification remain. Preserve the completed work and verification evidence.
```

## Project Snapshot

- App: native iOS SwiftUI pet care tracker.
- Current milestone: Stages 0 through 6 are complete. Functionality Stages 6.2–6.3 implement reminder recurrence deletion and automatic food and litter schedules. Stage 6.1 event history actions and combined Stage 6.4 physical-device verification remain.
- Persistence: SwiftData for app data, UserDefaults for device-local notification settings.
- Sync: explicit CloudKit is enabled in signed Debug builds for `iCloud.com.tammie.PetTrackerApp`; Release remains local-only until production schema deployment. See sync-design.md. Future multi-user household sharing remains an architectural goal.
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
- Active reminder rows open the editor. Confirmed deletion can skip one recurring occurrence or delete the series and its completed reminder history while retaining logged care events.
- Automatic food and litter event schedules create deterministic, timestamp-correct care events on the next app/sync processing pass without reminders or notifications.
- Stage 5.10 adds verified pet name/calorie-goal editing, general reminder creation/editing, Events +/confirmed deletion, and inline food/medication option creation.
- Reminder-to-event completion that can log care events.
- Local notification scheduling with device-local per-event overrides; global presentation is controlled in iPhone Settings.
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

Stage 5.9 is complete and committed. Stage 5.10 is complete and committed: final build, 83 unit tests, and all 21 UI tests passed. Stage 6 was subsequently requested and its code preparation is implemented; see its current status and sync-design.md. The user approved Health inside pet detail, weight/visits/procedures/general notes, Health last in Quick Add and included in Recent, and lb as the default weight unit. Do not enable CloudKit until the agreed pre-sync changes are settled. Changes are committed as requested.

Sync provisioning update (2026-09-15): team `UXV29Z3R2F`, bundle `com.tammie.PetTrackerApp`, and container `iCloud.com.tammie.PetTrackerApp` are configured. Keep code correctness, data preservation, offline behavior, and future multi-user/household sharing boundaries intact. Sharing UI, invitations, and permissions remain future scope.

Simulator cleanup: removed obsolete PetTracker installations from iPhone 17 Pro/Pro Max after backing up their app bundles and data to `/tmp/pettracker-obsolete-installations-20260913`. Both simulators were returned to shutdown. iPhone 17 retains the latest app; two normal launches succeeded. Reported launch crashes were the separate UI-test runner missing `lib_TestingInterop.dylib` when manually opened. Removed that runner; `scripts/test-ui.sh` now removes it after test success/failure and resolves cleanup from the actual destination. Mocked success/failure checks, shell syntax, and diff checks passed. Direct Xcode UI-test runs may still leave a runner installed.


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
- Private seed data and the personal simulator remain outside UI-test workflows. CloudKit Development is now configured and live-verified on the physical iPhone.


## Stage 6 code preparation (2026-09-13)

The user authorized Stage 6 while arranging an Apple developer account separately. The explicit CloudKit fallback is implemented behind repositories. Stage 6 originally preserved the local schema; Stage 6.3 later added `ScheduledEventRecord` through the tested additive SwiftData upgrade path. Read [sync-design.md](sync-design.md) before modifying sync; it defines scoped ownership, the version-1 wire contract, prepared-write recovery, tombstones, completion reconciliation, scheduling calendar, and future zone-wide household sharing.

The original code-readiness build passed, with 111 unit tests and 22 UI tests. On 2026-09-15, the signed physical app saved the populated phone dataset to the real Development container. An isolated physical-device integration test then passed against live CloudKit with two independent local contexts, all synced categories, empty-context download, offline/reconnect, and concurrent partial reminder completion. Tests use public fixtures and isolated stores; preserve the ignored private SeedData.local.swift without reading, changing, or staging it.

Signed Debug builds use CloudKit Development; Release remains local-only until production schema deployment. The iPhone 17 simulator account is blocked by an iCloud protected-key trust state (`waitfortrust`/`PCSNoPublicIdentity`), so its local app data was replaced with a verified copy of the phone dataset. That simulator limitation is not CloudKit evidence; the physical-device integration test is. Future sharing invitations/permissions/UI and background push remain outside Stage 6.

## Stages 6.2–6.3 implementation notes

- Active reminder rows open the existing editor; completed history remains read-only. Recurring delete confirmation offers a due-time-anchored occurrence skip or whole-series deletion. A deterministic synced skip record prevents a concurrent stale edit from recreating the skipped due instant. Delete All removes deterministic reminder history and pending notifications while keeping logged care events; tombstones win concurrent edits and completion records do not recreate the deleted series.
- `ScheduledEvent`, `ScheduledEventRecord`, and their repository/sync mappings model food-only automatic schedules separately from reminders. Stored food snapshots, calendar semantics, a resumable `nextDueAt` cursor, and deterministic schedule/timestamp event IDs preserve timestamps and avoid duplicates across retries/devices.
- The Reminders tab has a Scheduled Events section and a calendar/clock add button. Schedule add/edit/delete supports saved food, household or one pet, recurrence, and optional end date. The UI states that due events appear when the app next runs and retain their scheduled time.
- Due schedules materialize after launch/foreground refresh, schedule saves, and successful sync imports. Catch-up is chronological and bounded to 100 occurrences per schedule per pass; deleting a schedule leaves generated events.
- Final regression on 2026-09-15 passed all 119 unit/persistence/sync tests and all 23 UI tests. The result bundles are recorded in `plan.md`.
- Stage 6.1 event archive/restore/duplicate remains planned. Stage 6.4 still includes combined physical-iPhone upgrade/notification verification after Stage 6.1.

## Home interaction updates (2026-11-22)

The user updated the physical iPhone and confirmed existing data remained intact before this work.

- Home care/health rows no longer navigate on tap; left swipe offers Edit and confirmed Delete.
- Home reminder rows offer Edit/Delete on left swipe and Skip Instance on right swipe. Skipping advances the recurring due occurrence (or removes a one-off) without completion history or a logged event. Delete uses the same occurrence/series confirmation as Reminders.
- Recent includes every past care/health entry within 24 hours, extended to the latest 10 entries when needed, newest first with local-day headings. This supersedes Stage 5.9's latest-per-category/seven-day policy and Recent navigation links.
- Health deletion uses the existing local transaction and sync tombstone path. No schema change or reseeding is needed.
- Verification: build, all 123 unit/persistence/sync tests, and four focused UI workflows passed; evidence and initial test failures are recorded in plan.md. The Xcode shared scheme was already untracked when this work began; preserve it.

## November 22, 2026: Current screen refinement

Home interaction changes and the Events/Reminders/Notifications refinement are included in the follow-up commit after `7da7747`. The prior build was installed on the user's phone with data intact; these newer changes have not been installed on the phone.

Events + now sits beside the category heading. Food and litter creation can enable Recurring; schedules are managed in the initially collapsed Recurring section above the event log. Reminders has one inline + and no Mode selector. Optional Create Events entries support multiple types and pets; household entries log at first completion, and per-pet actions log together. Partially completed definitions retain their exact stored payloads. Settings > Notifications contains daily reminder time followed by per-type Use default overrides; global presentation is controlled through iPhone Settings.

Additive optional SwiftData fields retain legacy records. Sync envelope format 2 protects new action bundles and litter schedules from lossy interpretation by older clients. Update all syncing devices before using the new payloads. The 131-test unit suite passes, including an actual pre-change public simulator database-copy upgrade without reset. See plan.md for UI verification results.

Final verification: 131 unit tests and all 26 UI workflows pass across the full run plus focused reruns after fixes. Build and whitespace checks pass. Fixed the confirmation swipe animation crash as well as form keyboard/hit-area issues. Updated design/README/sync notes and plan evidence. The refinement is committed; the phone has not been updated with it.
