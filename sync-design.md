# Stage 6 sync design

Code preparation is implemented; live CloudKit provisioning and verification remain pending the user's Apple developer account. Normal builds stay local-only. The optional CloudKit configuration is not attached to any project build configuration.

## Integration choice

Use explicit CloudKit sync over the existing SwiftData repositories. SwiftData's documented managed configuration offers automatic/private database sync; the planned explicit fallback gives us control over record identities, completion reconciliation, and a future shared-database path. See [Apple: SwiftData CloudKit configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct).

The local SwiftData schema is unchanged, including its unique domain IDs. Its records are not passed to managed CloudKit mirroring, so managed-schema restrictions do not require removing local uniqueness or reseeding data. Every local container explicitly uses `.none`. A unit test creates a populated Stage 5 schema store, copies the entire store directory including SQLite sidecars, and opens the copy through the new factory, preserving pets, care history, Health, saved medication metadata, and completed reminder targets/history. Versioned migration will be required when the local schema actually changes; this milestone does not change it.

## Record and ownership boundaries

- `SyncPayload` version 1 covers pets, care events, Health, saved options, reminder definitions/targets, and completion records. Notification settings never enter the payload.
- One `PetTrackerEntityV1` CloudKit record per entity/completion, with a binary `envelope` field. Record names derive from stable domain UUIDs. Recurrence history and logged reminder events have deterministic IDs per reminder/due instant/pet.
- A personal household uses one custom zone, `PetTrackerHousehold`. `SyncScope` includes container, Development/Production environment, database, zone, and owner. Transport chooses the CloudKit database; UI/domain features do not.
- Journal files are scoped to container/environment. The first available account binds the journal; a different account pauses sync without importing/uploading its data. Account changes do not reset local history.
- Version-1 payload property/case names are a wire contract. Future changes need compatibility decoding or an explicit format upgrade, not a silent rename.

Future sharing can use a zone-wide `CKShare`: Apple documents that participants receive the zone in their shared database. See [Apple: zone-wide sharing](https://developer.apple.com/documentation/cloudkit/ckshare/init(recordzoneid:)). Invitations, permissions, and sharing UI remain future work. An accepted household must use its own local store/context and scoped journal; never initialize a participant's shared household by uploading their unrelated personal dataset. The current app selects one personal household, not multiple households simultaneously.

## Local durability and conflicts

`SyncJournal` retains authored records, a canonical local baseline, pending keys, and deletion tombstones. Local writes prepare the candidate journal before saving SwiftData. A failed local save rolls back and discards preparation. A successful local save with interrupted metadata commit keeps preparation for recovery: it is accepted only when its baseline matches the actual local snapshot. Recovery precedes binding, receiving, sending, and acknowledging. Acknowledgements clear only the exact version sent, so an edit made during a network request stays queued.

Entity edits use a Lamport counter and writer UUID. Equal versions have a deterministic value tie-break, including when a restored backup clones a writer identity. Deletion wins over edits; restoring an intentionally deleted identity is not an implicit sync operation.

Reminder completion is a separate record from the authored definition. Merge per-pet outcomes, use the earliest recorded completion for repeated submissions of the same target, and retain alternative event submissions in the ledger. Canonical target completion times produce one history entry and one next occurrence; actual event keys permit at most one logical event per target/occurrence. A later authored reminder edit takes precedence over projecting completion of an older definition, while completed history remains. Authored historical event edits/deletions survive completion replay.

Each reminder definition records its scheduling calendar/time zone, reused by completion projection. Recurrence therefore does not depend on the importing device's current time zone. Display and local notification preferences remain device-local. Stale completion sheets must be reopened; a previously completed due instant cannot be completed again by rescheduling back to it. Another actual event can be logged through Quick Add.

Imports validate the version, identity, payload, and resulting local snapshot. Unsupported/lossy mappings roll back instead of dropping fields or replacing valid local data. Existing reminder templates do not persist a food calorie-rate field; normal wire snapshots originate from persisted records, where that field is nil. An incoming template that requires this unsupported field is rejected until a schema/mapping upgrade supports it.

## Catch-up and offline behavior

The transport pages full-zone changes from a nil token, retaining record system fields in memory for optimistic `.ifServerRecordUnchanged` saves. Per-record conflicts return server envelopes for reconciliation and bounded retries. This initial personal-use implementation avoids persistent-token correctness dependencies; incremental fetch and asset-backed large payloads are future optimizations. Payloads over the conservative 800 KB guard remain local with an explanatory sync status; they are not truncated.

Sync runs on foreground entry, local writes, manual Sync Now, and every minute while active. Imported data refreshes the feature store and local notification schedule without relaunch. Silent/background push delivery is not implemented in this milestone. Signed-out/network failures keep changes local for retry. Unexpected server hard deletions or loss of an established zone pause sync; normal app deletions use durable tombstone records. Automatic destructive CloudKit reset/reseed is not available.

Local fetch/save errors are thrown and surfaced with retry. Fetches publish only after all repositories succeed. Unreadable records still count as existing data for initialization, preventing accidental reseeding. Startup container failures show a retry screen rather than terminate the app. Diagnostics log operation/error domain/code without private titles or notes.

## Activation after account setup

1. Confirm the signing team and register/select the actual iCloud container.
2. Use `Configuration/CloudKit.xcconfig.example` and its entitlement template as opt-in configuration. Replace `iCloud.YOUR_CONTAINER`, select Development/Production consistently, and verify the signed entitlements match the Info.plist container/environment. Do not attach this configuration to ordinary local builds prematurely.
3. Verify the development CloudKit schema for `PetTrackerEntityV1.envelope` and prepare production schema deployment when release work begins. Each environment gets a new journal for the existing local dataset; review that target account/dataset before first activation.
4. Back up populated local data and verify the upgrade on a copy; never reset personal history to make setup succeed.
5. Verify two same-account contexts: initial populated upload, empty second-context download without duplicate seeds, edits/deletes/Health/partial targets, concurrent completions, notification refresh, offline/reconnect, and signed-out/account-change behavior.

UI-test arguments and injected XCTest hosts use isolated local stores/defaults and cannot enable sync, including in CloudKit-flagged builds. UI tests use `UITests.store`; unit-test app hosts use `UnitTestHost.store`. Debug reset/reseed is disabled in a cloud-configured normal app. The full UI script removes its test runner afterward.

Local/model/mock checks are evidence of code readiness, not evidence that live CloudKit works. Stage 6 remains pending its account-dependent checks until those run successfully.
