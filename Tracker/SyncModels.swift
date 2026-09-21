import Foundation

/// What gets written to the shared file. Plain JSON on purpose — readable,
/// diffable, and not tied to SwiftData's private store format.
struct SyncEnvelope: Codable {
    var version = 1
    var writtenAt = Date()
    var tasks: [SyncTask] = []
    var goals: [SyncGoal] = []
    /// Record id → when it was deleted. Without these, a record deleted on one
    /// device would be resurrected by the other device's copy on the next merge.
    var deletions: [String: Date] = [:]
}

struct SyncTask: Codable {
    var uid: String
    var updatedAt: Date
    var title: String
    var notes: String
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?
    var startedAt: Date?
    var snoozedUntil: Date?
    var priorityRaw: Int
    var categoryRaw: Int
    var estimatedMinutes: Int
    var remindersEnabled: Bool
    var leadMinutes: Int
    var nagWhenOverdue: Bool
    var calendarEventID: String?
    var steps: [SyncStep]
}

struct SyncStep: Codable {
    var uid: String
    var updatedAt: Date
    var title: String
    var isDone: Bool
    var order: Int
    var createdAt: Date
    var completedAt: Date?
}

struct SyncGoal: Codable {
    var uid: String
    var updatedAt: Date
    var title: String
    var symbol: String
    var targetCount: Int
    var currentCount: Int
    var statusRaw: Int
    var createdAt: Date
    var isArchived: Bool
}

// MARK: - Converting to and from the SwiftData models

extension SyncTask {
    init(_ task: TaskItem) {
        uid = task.uid.uuidString
        updatedAt = task.updatedAt
        title = task.title
        notes = task.notes
        dueDate = task.dueDate
        createdAt = task.createdAt
        completedAt = task.completedAt
        startedAt = task.startedAt
        snoozedUntil = task.snoozedUntil
        priorityRaw = task.priorityRaw
        categoryRaw = task.categoryRaw
        estimatedMinutes = task.estimatedMinutes
        remindersEnabled = task.remindersEnabled
        leadMinutes = task.leadMinutes
        nagWhenOverdue = task.nagWhenOverdue
        calendarEventID = task.calendarEventID
        steps = task.orderedSteps.map(SyncStep.init)
    }

    /// Copies these values onto a model object, leaving its identity alone.
    func apply(to task: TaskItem) {
        task.title = title
        task.notes = notes
        task.dueDate = dueDate
        task.createdAt = createdAt
        task.completedAt = completedAt
        task.startedAt = startedAt
        task.snoozedUntil = snoozedUntil
        task.priorityRaw = priorityRaw
        task.categoryRaw = categoryRaw
        task.estimatedMinutes = estimatedMinutes
        task.remindersEnabled = remindersEnabled
        task.leadMinutes = leadMinutes
        task.nagWhenOverdue = nagWhenOverdue
        task.calendarEventID = calendarEventID
        task.updatedAt = updatedAt
    }
}

extension SyncStep {
    init(_ step: TaskStep) {
        uid = step.uid.uuidString
        updatedAt = step.updatedAt
        title = step.title
        isDone = step.isDone
        order = step.order
        createdAt = step.createdAt
        completedAt = step.completedAt
    }

    func apply(to step: TaskStep) {
        step.title = title
        step.isDone = isDone
        step.order = order
        step.createdAt = createdAt
        step.completedAt = completedAt
        step.updatedAt = updatedAt
    }
}

extension SyncGoal {
    init(_ goal: Goal) {
        uid = goal.uid.uuidString
        updatedAt = goal.updatedAt
        title = goal.title
        symbol = goal.symbol
        targetCount = goal.targetCount
        currentCount = goal.currentCount
        statusRaw = goal.statusRaw
        createdAt = goal.createdAt
        isArchived = goal.isArchived
    }

    func apply(to goal: Goal) {
        goal.title = title
        goal.symbol = symbol
        goal.targetCount = targetCount
        goal.currentCount = currentCount
        goal.statusRaw = statusRaw
        goal.createdAt = createdAt
        goal.isArchived = isArchived
        goal.updatedAt = updatedAt
    }
}
