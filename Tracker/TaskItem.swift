import Foundation
import SwiftData
import SwiftUI

enum Priority: Int, CaseIterable, Identifiable {
    case low = 0
    case normal = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    var tint: Color {
        switch self {
        case .low: return Bloom.inkSoft
        case .normal: return Bloom.lavender
        case .high: return Bloom.pink
        }
    }
}

@Model
final class TaskItem {
    /// A stable id that survives across launches, so notifications can point back
    /// at a task. `persistentModelID` isn't safe to stash in a notification payload.
    var uid: UUID = UUID()

    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var createdAt: Date = Date()
    /// Bumped on every edit. Sync uses it to decide which device's copy wins.
    var updatedAt: Date = Date()
    var completedAt: Date?
    var startedAt: Date?
    var snoozedUntil: Date?
    var priorityRaw: Int = Priority.normal.rawValue
    var categoryRaw: Int = TaskCategory.personal.rawValue
    /// Rough time this should take. 0 means the user didn't say.
    var estimatedMinutes: Int = 0
    var remindersEnabled: Bool = true
    var leadMinutes: Int = 30
    var nagWhenOverdue: Bool = true
    /// Set when this task was imported from Apple Calendar, so the original
    /// event stops being shown separately.
    var calendarEventID: String?

    /// Optional checklist of smaller steps. Optional rather than a plain array
    /// so existing stores migrate cleanly when this is added.
    @Relationship(deleteRule: .cascade, inverse: \TaskStep.task)
    var steps: [TaskStep]? = []

    init(
        title: String = "",
        notes: String = "",
        dueDate: Date? = nil,
        priority: Priority = .normal,
        category: TaskCategory = .personal,
        estimatedMinutes: Int = 0,
        remindersEnabled: Bool = true,
        leadMinutes: Int = 30,
        nagWhenOverdue: Bool = true
    ) {
        self.uid = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
        self.startedAt = nil
        self.snoozedUntil = nil
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.remindersEnabled = remindersEnabled
        self.leadMinutes = leadMinutes
        self.nagWhenOverdue = nagWhenOverdue
    }
}

extension TaskItem {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }

    var isInProgress: Bool { !isCompleted && startedAt != nil }

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > Date()
    }

    var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }

    var status: TaskStatus {
        if isCompleted { return .completed }
        if isOverdue { return .overdue }
        if isInProgress { return .inProgress }
        return .pending
    }

    /// `nil` when there was no deadline to judge it against.
    var completedOnTime: Bool? {
        guard let completedAt, let dueDate else { return nil }
        return completedAt <= dueDate
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled task" : title
    }

    // MARK: - Steps

    var orderedSteps: [TaskStep] {
        (steps ?? []).sorted { a, b in
            a.order == b.order ? a.createdAt < b.createdAt : a.order < b.order
        }
    }

    var hasSteps: Bool { !(steps ?? []).isEmpty }

    var completedStepCount: Int {
        (steps ?? []).filter(\.isDone).count
    }

    var stepCount: Int { (steps ?? []).count }

    /// 0...1 across the checklist, or nil when the task has no steps.
    var stepProgress: Double? {
        guard stepCount > 0 else { return nil }
        return Double(completedStepCount) / Double(stepCount)
    }

    /// "1.5 hr" / "20 min", or nil when no estimate was given.
    var durationLabel: String? {
        guard estimatedMinutes > 0 else { return nil }
        if estimatedMinutes < 60 { return "\(estimatedMinutes) min" }
        let hours = Double(estimatedMinutes) / 60
        return hours == hours.rounded()
            ? "\(Int(hours)) hr"
            : String(format: "%.1f hr", hours)
    }
}
