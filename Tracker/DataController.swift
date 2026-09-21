import Foundation
import SwiftData

/// Single owner of the SwiftData stack, so the notification delegate can reach the
/// same store the UI is using without going through the SwiftUI environment.
@MainActor
final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    private init() {
        let schema = Schema([TaskItem.self, TaskStep.self, Goal.self])
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
        } catch {
            // A corrupt store should never stop the app from opening. Fall back to
            // memory so the user can still add tasks and see what's wrong.
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }

    var context: ModelContext { container.mainContext }

    func allTasks() -> [TaskItem] {
        (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
    }

    func openTasks() -> [TaskItem] {
        allTasks().filter { !$0.isCompleted }
    }

    func task(uid: String) -> TaskItem? {
        guard let uuid = UUID(uuidString: uid) else { return nil }
        return allTasks().first { $0.uid == uuid }
    }

    func completeTask(uid: String) {
        guard let task = task(uid: uid) else { return }
        task.completedAt = Date()
        task.snoozedUntil = nil
        task.updatedAt = Date()
        save()
    }

    func snoozeTask(uid: String, hours: Int) {
        guard let task = task(uid: uid) else { return }
        task.snoozedUntil = Date().addingTimeInterval(Double(max(1, hours)) * 3600)
        task.updatedAt = Date()
        save()
    }

    /// Housekeeping so the completed list doesn't grow forever.
    @discardableResult
    func deleteCompleted(olderThanDays days: Int) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let stale = allTasks().filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt < cutoff
        }
        stale.forEach {
            SyncEngine.shared.recordDeletion($0.uid.uuidString)
            context.delete($0)
        }
        save()
        return stale.count
    }

    func goals() -> [Goal] {
        let all = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        return all.filter { !$0.isArchived }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Marking a task started is how it gets the "In Progress" badge.
    func toggleStarted(_ task: TaskItem) {
        task.startedAt = task.startedAt == nil ? Date() : nil
        save()
    }

    func save() {
        try? context.save()
    }
}
