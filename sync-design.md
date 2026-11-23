# Stage 6 sync design

Stage 6 is implemented and verified against the CloudKit Development environment. The app target is signed by team `UXV29Z3R2F`, uses `iCloud.com.tammie.PetTrackerApp`, and enables explicit CloudKit sync in Debug builds. Release builds remain local-only until the Development schema is deliberately deployed to Production.

## Integration choice

Use explicit CloudKit sync over the existing SwiftData repositories. SwiftData's documented managed configuration offers automatic/private database sync; the planned explicit fallback gives us control over record identities, completion reconciliation, and a future shared-database path. See [Apple: SwiftData CloudKit configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct).

SwiftData remains local and retains unique domain IDs. Its records are not passed to managed CloudKit mirroring, so managed-schema restrictions do not require removing local uniqueness or reseeding data. Every local container explicitly uses `.none`. Stage 6.3 adds an independent `ScheduledEventRecord` through SwiftData's additive lightweight upgrade path. The populated-store copy test opens the earlier store through the current factory and preserves pets, care history, Health, saved medication metadata, and completed reminder targets/history. A versioned migration remains required for future changes that lightweight migration cannot represent.

## Record and ownership boundaries

- Legacy `SyncPayload` version 1 covers pets, care events, Health, saved options, reminder definitions/targets, completion records, and automatic food schedules. Notification settings never enter the payload.
- One `PetTrackerEntityV1` CloudKit record per entity/completion, with a binary `envelope` field. Record names derive from stable domain UUIDs. Recurrence history and logged reminder events have deterministic IDs per reminder/due instant/pet.
- A personal household uses one custom zone, `PetTrackerHousehold`. `SyncScope` includes container, Development/Production environment, database, zone, and owner. Transport chooses the CloudKit database; UI/domain features do not.
- Journal files are scoped to container/environment. The first available account binds the journal; a different account pauses sync without importing/uploading its data. Account changes do not reset local history.
- Version-1 payload property/case names are a wire contract. Future changes need compatibility decoding or an explicit format upgrade, not a silent rename.

Future sharing can use a zone-wide `CKShare`: Apple documents that participants receive the zone in their shared database. See [Apple: zone-wide sharing](https://developer.apple.com/documentation/cloudkit/ckshare/init(recordzoneid:)). Invitations, permissions, and sharing UI remain future work. An accepted household must use its own local store/context and scoped journal; never initialize a participant's shared household by uploading their unrelated personal dataset. The current app selects one personal household, not multiple households simultaneously.

## Local durability and conflicts

`SyncJournal` retains authored records, a canonical local baseline, pending keys, and deletion tombstones. Local writes prepare the candidate journal before saving SwiftData. A failed local save rolls back and discards preparation. A successful local save with interrupted metadata commit keeps preparation for recovery: it is accepted only when its baseline matches the actual local snapshot. Recovery precedes binding, receiving, sending, and acknowledging. Acknowledgements clear only the exact version sent, so an edit made during a network request stays queued.

Entity edits use a Lamport counter and writer UUID. Equal versions have a deterministic value tie-break, including when a restored backup clones a writer identity. Deletion wins over edits; restoring an intentionally deleted identity is not an implicit sync operation.

Reminder completion is a separate record from the authored definition. Merge per-pet outcomes, use the earliest recorded completion for repeated submissions of the same target, and retain alternative event submissions in the ledger. Canonical target completion times produce one history entry and one next occurrence; actual event keys permit at most one logical event per action/occurrence (per target for legacy reminders). A later authored reminder edit takes precedence over projecting completion of an older definition, while completed history remains. Authored historical event edits/deletions survive completion replay.

Reminder occurrence deletion writes the advanced definition plus a deterministic `skip-<UUID>` record for the skipped due instant; it creates no completion/history record. Skip projection advances a concurrently edited definition that still targets the skipped instant, so a stale title edit cannot recreate that occurrence. Series deletion writes tombstones for the active definition and every deterministic history identity currently belonging to it. Tombstones beat concurrent edits and prevent retained completion records from projecting deleted definitions/history again; care-event records remain independent.

Automatic schedules use `schedule-<UUID>` records. Generated care-event identities derive from schedule ID plus scheduled timestamp, so two devices can materialize the same due occurrence and converge on one event. The schedule stores its authoring calendar and resumable `nextDueAt` cursor. Catch-up is chronological and bounded per pass; deleting the schedule tombstones only the schedule and keeps generated events.

Each reminder definition records its scheduling calendar/time zone, reused by completion projection. Recurrence therefore does not depend on the importing device's current time zone. Display and local notification preferences remain device-local. Stale completion sheets must be reopened; a previously completed due instant cannot be completed again by rescheduling back to it. Another actual event can be logged through Quick Add.

Imports validate the version, identity, payload, and resulting local snapshot. Unsupported/lossy mappings roll back instead of dropping fields or replacing valid local data. Existing reminder templates do not persist a food calorie-rate field; normal wire snapshots originate from persisted records, where that field is nil. An incoming template that requires this unsupported field is rejected until a schema/mapping upgrade supports it.

## Catch-up and offline behavior

The transport pages full-zone changes from a nil token, retaining record system fields in memory for optimistic `.ifServerRecordUnchanged` saves. Per-record conflicts return server envelopes for reconciliation and bounded retries. This initial personal-use implementation avoids persistent-token correctness dependencies; incremental fetch and asset-backed large payloads are future optimizations. Payloads over the conservative 800 KB guard remain local with an explanatory sync status; they are not truncated.

Sync runs on foreground entry, local writes, manual Sync Now, every minute while active, and after iOS posts `CKAccountChanged`. Imported data refreshes the feature store, materializes any due automatic food and litter schedules, and refreshes local notifications without relaunch. Silent/background push delivery is not implemented in this milestone. Signed-out/network failures keep changes local for retry. Unexpected server hard deletions or loss of an established zone pause sync; normal app deletions use durable tombstone records. Automatic destructive CloudKit reset/reseed is not available.

Local fetch/save errors are thrown and surfaced with retry. Fetches publish only after all repositories succeed. Unreadable records still count as existing data for initialization, preventing accidental reseeding. Startup container failures show a retry screen rather than terminate the app. Diagnostics log operation/error domain/code without private titles or notes.

## Provisioning and release activation

1. The signing team, app identifier, iCloud entitlement, Development environment, and `iCloud.com.tammie.PetTrackerApp` container are configured in the project. `Configuration/CloudKit.xcconfig.example` remains a reusable template for another app/container.
2. The Development schema contains `PetTrackerEntityV1.envelope`. Deploy that schema to Production only during release preparation, then enable `PETTRACKER_CLOUDKIT` for Release. Each environment gets a separate journal for the existing local dataset; review the target account and dataset before first activation.
3. Back up populated local data before provisioning changes; never reset personal history to make setup succeed.
4. Run `DEVICE_ID=<physical-device-UDID> scripts/test-cloudkit-live.sh` to verify the isolated live contract. The test creates a uniquely named private Development zone, exercises two independent local contexts, and removes the zone afterward.

UI-test arguments and injected XCTest hosts use isolated local stores/defaults and cannot enable sync, including in CloudKit-flagged builds. UI tests use `UITests.store`; unit-test app hosts use `UnitTestHost.store`. Debug reset/reseed is disabled in a cloud-configured normal app. The full UI script removes its test runner afterward.

Live verification on 2026-09-15 passed on the connected iPhone against the real Development container: an empty second local context downloaded all synced categories, offline edits uploaded after reconnect, and concurrent partial reminder completions converged without duplicate logical results. The app's populated phone dataset also produced real record saves in the Development container. The iPhone 17 simulator's iCloud protected-key state remained `waitfortrust`/`PCSNoPublicIdentity`; its local app data was replaced with a verified copy of the phone data, but that simulator is not evidence of CloudKit transport. This account-specific simulator limitation does not affect the isolated physical-device CloudKit result.

## November 2026 form and recurrence upgrade

Reminder records add optional `eventActionsJSON`; schedule records add optional `eventTypeRawValue`. Legacy reminder payloads and food schedules still decode. A copied public test database from before these fields upgrades without reset. Food scalar columns remain in place for compatibility.

Envelope format 2 is required for reminders with multiple event actions, their completion/skip records, and litter schedules. Other payloads retain format 1. New clients accept both; older clients reject version 2 rather than silently dropping actions or treating litter as food. Update all syncing devices before using these features. CloudKit record type and record identities remain unchanged.

Each reminder action has a stable UUID. Logged event identities derive from occurrence plus action UUID. Completion outcomes can contain multiple events, while legacy single-event outcomes still decode. Partial pet completion, concurrent household completion, recurring history, authored event edits, and deletion replay retain deterministic convergence. Household events log on the first pet completion and converge to the earliest outcome. Mixed reminders combine per-type notification presentation preferences, enabling each flag when any included type enables it.


## Next priority: household sharing and TestFlight (decision brief, 2026-11-22)

The user has deferred archive/restore/duplicate. First finish the current feature set; then prioritize sync between different users. The product decisions below are confirmed; the implementation approach remains a proposal. Sharing is not implemented, and publication is not authorized.

### Existing foundation and missing work

Private-account CloudKit sync is implemented for signed Debug builds. It has durable local writes, retries, tombstones, deterministic reminder reconciliation, and per-environment journals. Earlier isolated live testing used one iCloud account and two local contexts. That does not test two people. The transport can select a shared database, but app startup still binds one personal scope/store. There are no invitation, acceptance, participant-management, or shared-household switching flows. Foreground polling exists; background change handling does not.

### Options

| Option | Fit | Main cost or limitation |
| --- | --- | --- |
| Share one household through CloudKit `CKShare` (recommended) | Matches the existing iPhone/iCloud app and custom-zone records; no separate login service | Each person needs iCloud; owner/participant lifecycles and local store boundaries must be implemented |
| Share selected pets using CloudKit record hierarchies or separate zones | Useful if sitters should only see one pet | Current records are a flat household collection, including household litter and shared saved options; requires a partitioning design |
| Separate account/backend service | Consider if Android/web, non-iCloud accounts, or richer roles become near-term requirements | Adds authentication, server permissions, operations, and a substantial migration from the existing sync design |

Apple supports sharing a whole custom zone or a record hierarchy. A participant sees shared data through their shared database; the owner retains the source in their private database. Read/write participants can also delete shared records. These boundaries favor a whole-household first version if everyone should manage the same pets. [Apple: Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records).

Recommended initial shape: one selected household, one owner, invite-only adult caregivers with edit access, and device-local notification preferences. Use the system sharing UI for invitations and participant management. Keep personal and accepted-household stores and sync journals separate. Joining must never upload or merge a participant's unrelated personal dataset implicitly. The confirmed product decisions and remaining lifecycle questions are recorded below.

### Confirmed product decisions (2026-11-22)

- Everyone uses iPhone and iCloud.
- Share the entire household, including pets, health, medication, saved options, and history.
- All members have edit/delete access; no read-only member role.
- Reminders notify everyone by default. Each person controls their own notification preferences; changing one person's settings must not change another person's settings. Reminder definitions and completion state are shared.
- Household data remains with the household when a member leaves, including that person's logged events. Leaving must not cascade-delete authored records or erase their attribution. This specifies household retention, not whether a departing member keeps an offline copy.
- Show who logged events. Attribution must identify a caregiver, not the device writer UUID used for conflict resolution.
- An owner leaving while other members remain must designate a new owner. Proposed completion rule: the successor accepts and the data/access handoff is verified before the outgoing owner leaves.
- When the final member leaves, offer deletion of all household data or saving the household as a reloadable seed/backup file. Export must preserve history and attribution, not just starter options. This is an end-user file feature, separate from the private development seed source.

### Attribution and notification design implications

Proposed implementation: add optional creator identity and a display-name snapshot to logged care/health entries; preserve original authorship on edits and after a person leaves. Existing entries without reliable attribution must not be assigned to the current user retroactively. Label automatically generated recurring events as automatic; events generated by completing a reminder should identify the person who completed it. Keep deterministic event identities and completion reconciliation intact when adding attribution, including concurrent completions.

Personal notification preferences must stay outside the shared household payload. Completion sync should remove obsolete notifications on other devices when changes arrive. Background delivery and cancellation while the app is closed require real-device testing; do not promise immediate cancellation.

### Remaining lifecycle choices

- Joining: recommended default is to open the invited household separately, with no automatic merge/upload of existing personal data. Explicit import can be designed later.
- Ownership succession is confirmed above. Unexpected owner account loss or disappearance still needs a recovery policy; it cannot rely on the departing owner designating a successor.
- Departing member's device: decide whether to remove its local shared copy or retain a clearly labeled offline snapshot; stop shared writes and notifications after access ends. Already downloaded data cannot be assumed remotely erased.
- Initial scope: one active household is proposed; switching among multiple households is not yet agreed.
- Caregiver display names and how to handle pending offline edits after revocation need implementation details. “Logged by” is confirmed; a full edit audit trail is not requested.

### Owner handoff and final-member closure

Product ownership and CloudKit storage ownership must both be addressed. Apple documents `CKShare.owner` as read-only and places shared records in the owner's private database. A household owner field alone therefore does not establish a storage handoff. Validate the supported handoff approach before committing to the sharing architecture; a migration into the successor's zone with a replacement share may be required. Preserve logical record identities, authorship, history, recurrence cursors, and pending edits, and verify remaining members regain access before retiring the old share. [Apple: CKShare](https://developer.apple.com/documentation/cloudkit/ckshare), [Apple: owner](https://developer.apple.com/documentation/cloudkit/ckshare/owner).

Final-member closure is a deliberate flow with Cancel, Delete all household data, or Save a reloadable seed file. Proposed export behavior: save a versioned data archive, validate that it can be read back, and only then complete closure. A cancelled/failed export must leave the household intact. Restore must rebuild data without restoring obsolete sharing credentials or membership. Decide restore-time behavior for overdue reminders and recurring schedules so loading an old file cannot silently generate an unexpected backlog. Deletion covers the app's household cloud/local data and pending notifications; separately saved files remain under the user's control. No deletion or export is being executed by recording these requirements.

Required tests include accepted/interrupted/retried owner handoff, retained event authorship, last-member deletion, cancelled/failed export, full archive round-trip, and restore recurrence handling. These lifecycle features belong to the multi-user milestone; deferred event archive/restore/duplicate remains separate.

### Sharing implementation gates

- Add invitation creation/acceptance and `CKSharingSupported`, handling cold launch and already-running acceptance. [Apple sharing sample](https://developer.apple.com/documentation/cloudkit/sharing-cloudkit-data-with-other-icloud-users).
- Bind the accepted owner/zone/database to a separate local store and journal. Prevent writes after access is revoked or unavailable; no read-only member role is planned. Keep pending edits scoped to their original household.
- Verify with two real devices and different iCloud accounts: invite/accept, all data categories, offline edits, concurrent mixed reminder completion, scheduled litter/food catch-up, delete versus edit, leave/revoke, account changes, and app restart. In-memory two-context tests supplement this but do not replace it.
- Test notify-everyone behavior and independent personal preferences with each app foregrounded, backgrounded, and closed. Add background refresh/subscriptions where appropriate without promising immediate delivery.

### Where TestFlight fits

TestFlight is a distribution step, not a prerequisite for implementing or initially testing sharing. We can develop using registered devices first. Recommended sequence: current-app baseline → agree sharing scope → prove invite/join/sync with two accounts → prepare Production → invite a small TestFlight household pilot. An earlier owner-only TestFlight build is possible if easier installation is useful, but it still needs the release checks below. Public App Store release is a later, separate decision.

TestFlight uses CloudKit Production, not Development. [Apple: Testing Your CloudKit App](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/TestingYourApp/TestingYourApp.html). Deploying the schema copies types/fields/indexes but **does not copy existing records**; Production schema evolution is additive. [Apple: Deploying an iCloud Container’s Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).

Before a sync-enabled TestFlight build:

- Preserve a verified backup and reconcile current Development/local data. Choose one authoritative populated device for the initial Production upload, then test another clean device downloading it. Environment changes preserve the local store but initialize a separate journal; independently bootstrapping divergent old datasets is not a migration plan.
- Review/deploy the current schema to Production, deliberately enable `PETTRACKER_CLOUDKIT` for Release, and verify the archived app's signing entitlements/environment. The present Release configuration is local-only. Keep the same bundle identifier for the intended in-place upgrade and verify persistence on-device.
- Ensure private seed source is absent from the Release compilation; fresh installations start empty. Check app version/build number, app icon, required App Store Connect beta/contact/compliance metadata, and actual upgrade/install behavior.
- Run Production smoke tests before inviting others, including offline/reconnect and persistence after reinstall on a separate test device. Never uninstall the only populated personal copy as a test.
- Start with an internal group for the developer; household members who are not App Store Connect users should use an external invite-only group. Apple's first external build needs TestFlight App Review. TestFlight distribution does not require a public listing. [Apple: TestFlight](https://developer.apple.com/testflight/), [Apple: Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).

Production schema deployment, account changes, sharing invitations, and TestFlight upload/distribution have not been performed in this finalization pass.
