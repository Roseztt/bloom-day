import Foundation
import SwiftData

/// Shared mutations so Home, Tasks and Calendar all behave identically and every
/// change reschedules the reminders.
@MainActor
enum TaskActions {
    static func toggleDone(_ task: TaskItem, context: ModelContext) {
        task.completedAt = task.isCompleted ? nil : Date()
        task.snoozedUntil = nil
        if task.isCompleted { task.startedAt = nil }
        task.updatedAt = Date()
        persist(context)
    }

    static func toggleStarted(_ task: TaskItem, context: ModelContext) {
        task.startedAt = task.startedAt == nil ? Date() : nil
        task.updatedAt = Date()
        persist(context)
    }

    static func delete(_ task: TaskItem, context: ModelContext) {
        // Tombstone first, so sync doesn't resurrect it from another device.
        SyncEngine.shared.recordDeletion(task.uid.uuidString)
        (task.steps ?? []).forEach { SyncEngine.shared.recordDeletion($0.uid.uuidString) }
        context.delete(task)
        persist(context)
    }

    /// Turns an Apple Calendar event into a task. The event id is kept so the
    /// original stops showing as a separate calendar row.
    @discardableResult
    static func importEvent(_ event: CalendarEvent, context: ModelContext) -> TaskItem {
        let minutes = max(0, Int(event.end.timeIntervalSince(event.start) / 60))
        let task = TaskItem(
            title: event.title,
            notes: event.location ?? "",
            dueDate: event.start,
            category: .personal,
            estimatedMinutes: event.isAllDay ? 0 : min(minutes, 24 * 60),
            leadMinutes: SettingsStore.shared.defaultLeadMinutes
        )
        task.calendarEventID = event.id
        task.updatedAt = Date()
        context.insert(task)
        persist(context)
        return task
    }

    // MARK: - Steps

    static func addStep(_ title: String, to task: TaskItem, context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let step = TaskStep(title: trimmed, order: (task.steps ?? []).count)
        step.task = task
        context.insert(step)
        task.steps = (task.steps ?? []) + [step]
        task.updatedAt = Date()
        persist(context)
    }

    /// Ticking the last step finishes the task; un-ticking one reopens it. Keeps
    /// the checklist and the task's own state from contradicting each other.
    static func toggleStep(_ step: TaskStep, context: ModelContext) {
        step.isDone.toggle()
        step.completedAt = step.isDone ? Date() : nil
        step.updatedAt = Date()

        if let task = step.task, task.stepCount > 0 {
            let allDone = task.completedStepCount == task.stepCount
            if allDone && !task.isCompleted {
                task.completedAt = Date()
                task.startedAt = nil
                task.snoozedUntil = nil
                task.updatedAt = Date()
            } else if !allDone && task.isCompleted {
                task.completedAt = nil
                task.updatedAt = Date()
            }
        }

        persist(context)
    }

    static func deleteStep(_ step: TaskStep, context: ModelContext) {
        SyncEngine.shared.recordDeletion(step.uid.uuidString)
        if let task = step.task {
            task.updatedAt = Date()
            task.steps = (task.steps ?? []).filter { $0.persistentModelID != step.persistentModelID }
        }
        context.delete(step)
        persist(context)
    }

    static func reorderSteps(_ ordered: [TaskStep], context: ModelContext) {
        for (index, step) in ordered.enumerated() {
            step.order = index
            step.updatedAt = Date()
        }
        persist(context)
    }

    private static func persist(_ context: ModelContext) {
        try? context.save()
        NotificationManager.shared.refreshSchedule()
    }
}
