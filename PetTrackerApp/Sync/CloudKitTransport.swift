import CloudKit
import Foundation
import OSLog
import SwiftData

struct SyncSendResult {
    var acknowledged: [SyncEnvelope] = []
    var conflicts: [SyncEnvelope] = []
}

@MainActor
protocol SyncTransport {
    func accountIdentity() async throws -> String
    func prepare(scope: SyncScope, mayCreateZone: Bool) async throws
    func fetch(scope: SyncScope) async throws -> [SyncEnvelope]
    func send(_ changes: [SyncEnvelope], scope: SyncScope) async throws -> SyncSendResult
}

// Constructed only in an explicitly configured CloudKit build, never UI tests or local-only builds.
@MainActor
final class CloudKitTransport: SyncTransport {
    static let recordType = "PetTrackerEntityV1"
    private let container: CKContainer
    private let containerIdentifier: String
    private let environment: SyncScope.Environment
    private var fetchedRecords: [CKRecord.ID: CKRecord] = [:]

    init(containerIdentifier: String, environment: SyncScope.Environment = .development) {
        self.environment = environment
        self.containerIdentifier = containerIdentifier
        container = CKContainer(identifier: containerIdentifier)
    }

    private func database(_ scope: SyncScope) -> CKDatabase {
        scope.database == .private ? container.privateCloudDatabase : container.sharedCloudDatabase
    }
    private func zoneID(_ scope: SyncScope) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: scope.zoneName,
            ownerName: scope.ownerName == "currentUser" ? CKCurrentUserDefaultName : scope.ownerName)
    }

    func accountIdentity() async throws -> String {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            let error = error as NSError
            Logger(subsystem: "com.tammie.PetTrackerApp", category: "CloudKit")
                .error("Account lookup failed: \(error.domain, privacy: .public) code \(error.code)")
            throw error
        }
        guard status == .available else {
            Logger(subsystem: "com.tammie.PetTrackerApp", category: "CloudKit")
                .error("iCloud account unavailable: \(Self.name(for: status), privacy: .public)")
            throw SyncError.unavailable
        }
        do {
            return try await container.userRecordID().recordName
        } catch {
            let error = error as NSError
            Logger(subsystem: "com.tammie.PetTrackerApp", category: "CloudKit")
                .error("Account identity failed: \(error.domain, privacy: .public) code \(error.code)")
            throw error
        }
    }

    private static func name(for status: CKAccountStatus) -> String {
        switch status {
        case .available: "available"
        case .couldNotDetermine: "couldNotDetermine"
        case .noAccount: "noAccount"
        case .restricted: "restricted"
        case .temporarilyUnavailable: "temporarilyUnavailable"
        @unknown default: "unknown"
        }
    }

    func prepare(scope: SyncScope, mayCreateZone: Bool) async throws {
        guard scope.containerIdentifier == containerIdentifier && scope.environment == environment else {
            throw SyncError.unsupportedState
        }
        let database = database(scope)
        let id = zoneID(scope)
        do { _ = try await database.recordZone(for: id) } catch let error as CKError
            where error.code == .zoneNotFound || error.code == .unknownItem
        {
            guard mayCreateZone, scope.database == .private else { throw SyncError.unexpectedRemoteDeletion }
            _ = try await database.save(CKRecordZone(zoneID: id))
        }
    }

    func fetch(scope: SyncScope) async throws -> [SyncEnvelope] {
        guard scope.containerIdentifier == containerIdentifier && scope.environment == environment else {
            throw SyncError.unsupportedState
        }
        let database = database(scope)
        var token: CKServerChangeToken?
        var values: [SyncEnvelope] = []
        var cache: [CKRecord.ID: CKRecord] = [:]
        // Personal-use full-zone catch-up: no query indexes or persisted token that could skip data.
        // Pagination is mandatory. Tombstones are ordinary records and remain downloadable.
        while true {
            let page = try await database.recordZoneChanges(inZoneWith: zoneID(scope), since: token)
            guard !page.deletions.contains(where: { $0.recordType == Self.recordType }) else {
                throw SyncError.unexpectedRemoteDeletion
            }
            for result in page.modificationResultsByID.values {
                let record = try result.get().record
                guard record.recordType == Self.recordType else { continue }
                values.append(try Self.envelope(from: record))
                cache[record.recordID] = record
            }
            token = page.changeToken
            if !page.moreComing { break }
        }
        fetchedRecords = cache
        return values
    }

    func send(_ changes: [SyncEnvelope], scope: SyncScope) async throws -> SyncSendResult {
        guard scope.containerIdentifier == containerIdentifier && scope.environment == environment else {
            throw SyncError.unsupportedState
        }
        var reply = SyncSendResult()
        let database = database(scope)
        for offset in stride(from: 0, to: changes.count, by: 200) {
            let batch = Array(changes[offset..<min(offset + 200, changes.count)])
            let records = try batch.map { envelope in
                let id = CKRecord.ID(recordName: envelope.key, zoneID: zoneID(scope))
                let record = fetchedRecords[id] ?? CKRecord(recordType: Self.recordType, recordID: id)
                let data = try SyncCoding.encode(envelope.validated())
                guard data.count <= 800_000 else { throw SyncError.recordTooLarge }
                record["envelope"] = data as CKRecordValue
                return record
            }
            let results = try await database.modifyRecords(
                saving: records, deleting: [],
                savePolicy: .ifServerRecordUnchanged, atomically: false)
            for (id, result) in results.saveResults {
                switch result {
                case .success(let record):
                    fetchedRecords[id] = record
                    reply.acknowledged.append(try Self.envelope(from: record))
                case .failure(let error):
                    guard let cloudError = error as? CKError, cloudError.code == .serverRecordChanged,
                        let server = cloudError.serverRecord
                    else { throw error }
                    fetchedRecords[id] = server
                    reply.conflicts.append(try Self.envelope(from: server))
                }
            }
        }
        return reply
    }

    static func envelope(from record: CKRecord) throws -> SyncEnvelope {
        guard record.recordType == recordType, let data = record["envelope"] as? Data else {
            throw SyncError.invalidRecord
        }
        let envelope = try SyncCoding.decode(SyncEnvelope.self, from: data).validated()
        guard envelope.key == record.recordID.recordName else { throw SyncError.invalidRecord }
        return envelope
    }
}

enum SyncBuildConfiguration {
    static var environment: SyncScope.Environment? {
        #if PETTRACKER_CLOUDKIT
            #if DEBUG
                return .development
            #else
                return .production
            #endif
        #else
            return nil
        #endif
    }
    static var containerIdentifier: String? {
        #if PETTRACKER_CLOUDKIT
            guard environment != nil, !UITestConfiguration.isEnabled, NSClassFromString("XCTestCase") == nil,
                ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
            else { return nil }
            return "iCloud.com.tammie.PetTrackerApp"
        #else
            return nil
        #endif
    }
}

@MainActor
final class SyncCoordinator {
    private let journal: SyncJournal
    private let transport: SyncTransport
    private let context: ModelContext
    private weak var store: PetCareStore?
    private var running = false
    private var requested = false

    init(journal: SyncJournal, transport: SyncTransport, context: ModelContext, store: PetCareStore) {
        self.journal = journal
        self.transport = transport
        self.context = context
        self.store = store
    }

    func requestSync() { Task { await syncNow() } }

    func syncNow() async {
        if running {
            requested = true
            return
        }
        running = true
        defer { running = false }
        store?.syncStatus = "Syncing with iCloud…"
        do {
            let identity = try await transport.accountIdentity()
            try journal.bind(accountID: identity, context: context)
            try await transport.prepare(
                scope: journal.state.scope, mayCreateZone: !journal.state.cloudInitialized)
            // Bound retries also handle edits made locally while awaiting a network response.
            for _ in 0..<5 {
                try Task.checkCancellation()
                requested = false
                let remote = try await transport.fetch(scope: journal.state.scope)
                try Task.checkCancellation()
                try journal.receive(remote, context: context)
                try journal.markCloudInitialized(context: context)
                if store?.refreshFromPersistence() == true {
                    store?.materializeScheduledEvents()
                    store?.syncLocalNotifications()
                }
                let pending = try journal.pending(context: context)
                if pending.isEmpty && !requested { break }
                let reply = try await transport.send(pending, scope: journal.state.scope)
                try journal.acknowledge(reply.acknowledged, context: context)
                if !reply.conflicts.isEmpty {
                    try journal.receive(reply.conflicts, context: context)
                    if store?.refreshFromPersistence() == true {
                        store?.materializeScheduledEvents()
                        store?.syncLocalNotifications()
                    }
                }
            }
            let remaining = try journal.pending(context: context)
            store?.syncStatus =
                remaining.isEmpty ? "Up to date with iCloud" : "Changes saved here; sync will retry."
        } catch is DecodingError {
            store?.syncStatus = "Sync data couldn’t be read. Sync is paused; local data is kept."
        } catch is CancellationError {
            return
        } catch SyncError.invalidRecord, SyncError.unsupportedState {
            store?.syncStatus = "Sync data couldn’t be read. Sync is paused; local data is kept."
        } catch SyncError.recordTooLarge {
            store?.syncStatus = "An entry is too large to sync. Your data is saved on this device."
        } catch SyncError.accountChanged {
            store?.syncStatus = "iCloud account changed. Sync is paused to keep accounts separate."
        } catch SyncError.unexpectedRemoteDeletion {
            store?.syncStatus =
                "iCloud data was removed or access changed. Sync is paused; local data is kept."
        } catch {
            store?.syncStatus = "iCloud unavailable. Changes are saved on this device; sync will retry."
        }
    }
}
