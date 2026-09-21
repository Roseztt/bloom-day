import Foundation
import SwiftData

/// One small step inside a task — the checklist you tick off as you go.
@Model
final class TaskStep {
    var title: String = ""
    var isDone: Bool = false
    /// Position in the list. Kept explicit so reordering survives relaunches.
    var order: Int = 0
    /// Stable across devices, so sync can match this step to its twin.
    var uid: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?

    var task: TaskItem?

    init(title: String = "", order: Int = 0) {
        self.title = title
        self.isDone = false
        self.order = order
        self.createdAt = Date()
        self.updatedAt = Date()
        self.uid = UUID()
    }
}

extension TaskStep {
    var displayTitle: String {
        title.isEmpty ? "Untitled step" : title
    }
}
