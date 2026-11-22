# Stage 6 sync design

Stage 6 is implemented and verified against the CloudKit Development environment. The app target is signed by team `UXV29Z3R2F`, uses `iCloud.com.tammie.PetTrackerApp`, and enables explicit CloudKit sync in Debug builds. Release builds remain local-only until the Development schema is deliberately deployed to Production.

## Integration choice

Use explicit CloudKit sync over the existing SwiftData repositories. SwiftData's documented managed configuration offers automatic/private database sync; the planned explicit fallback gives us control over record identities, completion reconciliation, and a future shared-database path. See [Apple: SwiftData CloudKit configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct).

SwiftData remains local and retains unique domain IDs. Its records are not passed to managed CloudKit mirroring, so managed-schema restrictions do not require removing local uniqueness or reseeding data. Every local container explicitly uses `.none`. Stage 6.3 adds an independent `ScheduledEventRecord` through SwiftData's additive lightweight upgrade path. The populated-store copy test opens the earlier store through the current factory and preserves pets, care history, Health, saved medication metadata, and completed reminder targets/history. A versioned migration remains required for future changes that lightweight migration cannot represent.

## Record and ownership boundaries

- Legacy `SyncPayload` version 1 covers pets, care events, Health, saved options, reminder definitions/targets, completion records, and automatic food and litter schedules. Notification settings never enter the payload.
- One `PetTrackerEntityV1` CloudKit record per entity/completion, with a binary `envelope` field. Record names derive from stable domain UUIDs. Recurrence history and logged reminder events have deterministic IDs per reminder/due instant/pet.
- A personal household uses one custom zone, `PetTrackerHousehold`. `SyncScope` includes container, Development/Production environment, database, zone, and owner. Transport chooses the CloudKit database; UI/domain features do not.
- Journal files are scoped to container/environment. The first available account binds the journal; a different account pauses sync without importing/uploading its data. Account changes do not reset local history.
- Version-1 payload property/case names are a wire contract. Future changes need compatibility decoding or an explicit format upgrade, not a silent rename.

Future sharing can use a zone-wide `CKShare`: Apple documents that participants receive the zone in their shared database. See [Apple: zone-wide sharing](https://developer.apple.com/documentation/cloudkit/ckshare/init(recordzoneid:)). Invitations, permissions, and sharing UI remain future work. An accepted household must use its own local store/context and scoped journal; never initialize a participant's shared household by uploading their unrelated personal dataset. The current app selects one personal household, not multiple households simultaneously.

## Local durability and conflicts

`SyncJournal` retains authored records, a canonical local baseline, pending keys, and deletion tombstones. Local writes prepare the candidate journal before saving SwiftData. A failed local save rolls back and discards preparation. A successful local save with interrupted metadata commit keeps preparation for recovery: it is accepted only when its baseline matches the actual local snapshot. Recovery precedes binding, receiving, sending, and acknowledging. Acknowledgements clear only the exact version sent, so an edit made during a network request stays queued.

Entity edits use a Lamport counter and writer UUID. Equal versions have a deterministic value tie-break, including when a restored backup clones a writer identity. Deletion wins over edits; restoring an intentionally deleted identity is not an implicit sync operation.

Reminder completion is a separate record from the authored definition. Merge per-pet outcomes, use the earliest recorded completion for repeated submissions of the same target, and retain alternative event submissions in the ledger. Canonical target completion times produce one history entry and one next occurrence; actual event keys permit at most one logical event per target/occurrence. A later authored reminder edit takes precedence over projecting completion of an older definition, while completed history remains. Authored historical event edits/deletions survive completion replay.

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
