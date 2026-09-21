import Foundation
import Observation
import SwiftData
import SwiftUI

/// Syncs through a single JSON file in a folder you pick — typically one in
/// iCloud Drive, so Apple moves the file between your devices and we don't need
/// a server or the paid iCloud entitlement.
///
/// Not live: it reads and writes on launch, on foreground, and on demand. Merge
/// is per record, newest `updatedAt` wins, with tombstones so a delete on one
/// device isn't undone by the other's stale copy.
@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    enum Status: Equatable {
        case notSetUp
        case idle(Date?)
        case syncing
        case failed(String)
    }

    private(set) var status: Status = .notSetUp

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let bookmarkKey = "syncFolderBookmark"
    @ObservationIgnored private let lastSyncKey = "syncLastDate"
    @ObservationIgnored private let deletionsKey = "syncDeletions"
    @ObservationIgnored private let fileName = "bloom-day.json"

    private init() {
        status = defaults.data(forKey: bookmarkKey) == nil
            ? .notSetUp
            : .idle(defaults.object(forKey: lastSyncKey) as? Date)
    }

    var isConfigured: Bool {
        defaults.data(forKey: bookmarkKey) != nil
    }

    var folderName: String? {
        resolveFolder()?.lastPathComponent
    }

    // MARK: - Folder

    /// Stores a security-scoped bookmark to the folder the user picked. This is
    /// what lets us keep writing there on later launches without asking again,
    /// and it needs no entitlement.
    func useFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: bookmarkKey)
            status = .idle(nil)
        } catch {
            status = .failed("Couldn't keep access to that folder: \(error.localizedDescription)")
        }
    }

    func forgetFolder() {
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: lastSyncKey)
        status = .notSetUp
    }

    private func resolveFolder() -> URL? {
        guard let bookmark = defaults.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale, let refreshed = try? url.bookmarkData() {
            defaults.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    // MARK: - Deletion tombstones

    private var deletions: [String: Date] {
        get {
            guard
                let data = defaults.data(forKey: deletionsKey),
                let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            // Forget old tombstones so the file doesn't grow forever.
            let cutoff = Date().addingTimeInterval(-90 * 86_400)
            let trimmed = newValue.filter { $0.value > cutoff }
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: deletionsKey)
            }
        }
    }

    /// Called whenever something is deleted locally.
    func recordDeletion(_ uid: String) {
        var current = deletions
        current[uid] = Date()
        deletions = current
    }

    // MARK: - Syncing

    func syncIfConfigured() async {
        guard isConfigured else { return }
        await sync()
    }

    func sync() async {
        guard let folder = resolveFolder() else {
            status = .notSetUp
            return
        }

        status = .syncing

        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let fileURL = folder.appendingPathComponent(fileName)

        do {
            let remote = try readEnvelope(at: fileURL)
            let merged = merge(remote: remote)
            try writeEnvelope(merged, to: fileURL)

            let now = Date()
            defaults.set(now, forKey: lastSyncKey)
            status = .idle(now)
            NotificationManager.shared.refreshSchedule()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - File IO

    private func readEnvelope(at url: URL) throws -> SyncEnvelope {
        // Nudge iCloud into pulling the file down if it's still a placeholder.
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return SyncEnvelope()
        }

        var readError: NSError?
        var result: SyncEnvelope?
        var thrown: Error?

        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &readError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                result = try Self.decoder.decode(SyncEnvelope.self, from: data)
            } catch {
                // An empty or half-written file shouldn't wipe local data.
                thrown = error
            }
        }

        if let readError { throw readError }
        if result == nil, thrown != nil { return SyncEnvelope() }
        return result ?? SyncEnvelope()
    }

    private func writeEnvelope(_ envelope: SyncEnvelope, to url: URL) throws {
        let data = try Self.encoder.encode(envelope)

        var writeError: NSError?
        var thrown: Error?

        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &writeError
        ) { writeURL in
            do {
                try data.write(to: writeURL, options: .atomic)
            } catch {
                thrown = error
            }
        }

        if let writeError { throw writeError }
        if let thrown { throw thrown }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Merge

private extension SyncEngine {

    /// Reconciles the file with the local store and returns what should be
    /// written back. Per record, the newer `updatedAt` wins.
    func merge(remote: SyncEnvelope) -> SyncEnvelope {
        let controller = DataController.shared
        let context = controller.context

        var tombstones = deletions
        for (uid, date) in remote.deletions where (tombstones[uid] ?? .distantPast) < date {
            tombstones[uid] = date
        }

        // --- Tasks ---
        var localTasks = Dictionary(
            uniqueKeysWithValues: controller.allTasks().map { ($0.uid.uuidString, $0) }
        )

        for incoming in remote.tasks {
            // A delete beats an edit only if the delete happened later.
            if let deletedAt = tombstones[incoming.uid], deletedAt > incoming.updatedAt { continue }

            if let existing = localTasks[incoming.uid] {
                if incoming.updatedAt > existing.updatedAt {
                    incoming.apply(to: existing)
                    mergeSteps(incoming.steps, into: existing, tombstones: tombstones, context: context)
                }
            } else {
                let task = TaskItem()
                task.uid = UUID(uuidString: incoming.uid) ?? UUID()
                incoming.apply(to: task)
                context.insert(task)
                localTasks[incoming.uid] = task
                mergeSteps(incoming.steps, into: task, tombstones: tombstones, context: context)
            }
        }

        // Anything the other device deleted after our last edit goes here too.
        for (uid, task) in localTasks {
            if let deletedAt = tombstones[uid], deletedAt > task.updatedAt {
                context.delete(task)
                localTasks.removeValue(forKey: uid)
            }
        }

        // --- Goals ---
        var localGoals = Dictionary(
            uniqueKeysWithValues: controller.goals().map { ($0.uid.uuidString, $0) }
        )

        for incoming in remote.goals {
            if let deletedAt = tombstones[incoming.uid], deletedAt > incoming.updatedAt { continue }

            if let existing = localGoals[incoming.uid] {
                if incoming.updatedAt > existing.updatedAt {
                    incoming.apply(to: existing)
                }
            } else {
                let goal = Goal()
                goal.uid = UUID(uuidString: incoming.uid) ?? UUID()
                incoming.apply(to: goal)
                context.insert(goal)
                localGoals[incoming.uid] = goal
            }
        }

        for (uid, goal) in localGoals {
            if let deletedAt = tombstones[uid], deletedAt > goal.updatedAt {
                context.delete(goal)
                localGoals.removeValue(forKey: uid)
            }
        }

        controller.save()
        deletions = tombstones

        return SyncEnvelope(
            writtenAt: Date(),
            tasks: controller.allTasks().map(SyncTask.init),
            goals: controller.goals().map(SyncGoal.init),
            deletions: tombstones
        )
    }

    func mergeSteps(
        _ incoming: [SyncStep],
        into task: TaskItem,
        tombstones: [String: Date],
        context: ModelContext
    ) {
        var existing = Dictionary(
            uniqueKeysWithValues: (task.steps ?? []).map { ($0.uid.uuidString, $0) }
        )

        for step in incoming {
            if let deletedAt = tombstones[step.uid], deletedAt > step.updatedAt { continue }

            if let match = existing[step.uid] {
                if step.updatedAt > match.updatedAt {
                    step.apply(to: match)
                }
            } else {
                let created = TaskStep()
                created.uid = UUID(uuidString: step.uid) ?? UUID()
                step.apply(to: created)
                created.task = task
                context.insert(created)
                existing[step.uid] = created
            }
        }

        task.steps = Array(existing.values)
    }
}
