import Foundation
import UserNotifications

/// Builds and installs the whole local-notification schedule from the current tasks.
///
/// iOS only keeps a limited number of pending local notifications per app, so
/// rather than adding and removing individual requests we rebuild the entire
/// schedule from scratch whenever anything changes, keeping the soonest ones.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    static let taskIDKey = "taskID"
    static let categoryID = "TASK_REMINDER"
    static let digestCategoryID = "DAILY_DIGEST"
    static let completeActionID = "COMPLETE_TASK"
    static let snoozeActionID = "SNOOZE_TASK"

    private static let digestRequestID = "daily-digest"

    /// iOS caps pending local notifications at 64. Leave headroom for the repeating
    /// daily summary and for anything the system adds on our behalf.
    private let pendingBudget = 56

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Setup

    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: Self.completeActionID,
            title: "Mark Done",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze",
            options: []
        )

        let reminder = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        let digest = UNNotificationCategory(
            identifier: Self.digestCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([reminder, digest])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: - Scheduling

    /// Rebuilds every pending reminder from the current state of the task list.
    func refreshSchedule() {
        let tasks = DataController.shared.openTasks()
        let settings = SettingsStore.shared

        var combined = buildPlans(for: tasks, settings: settings)
        if settings.eventRemindersEnabled {
            let imported = Set(DataController.shared.allTasks().compactMap(\.calendarEventID))
            combined += buildEventPlans(excluding: imported, settings: settings)
        }
        let plans = finalise(combined, settings: settings)

        center.removeAllPendingNotificationRequests()

        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.categoryIdentifier = plan.categoryID
            content.interruptionLevel = plan.isUrgent ? .timeSensitive : .active
            if let taskID = plan.taskID {
                content.userInfo = [Self.taskIDKey: taskID]
            }

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: plan.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }

        if settings.dailyDigestEnabled {
            scheduleDailyDigest(openTasks: tasks, settings: settings)
        }

        let overdue = tasks.filter(\.isOverdue).count
        center.setBadgeCount(overdue) { _ in }
    }

    private struct Plan {
        var id: String
        var date: Date
        var title: String
        var body: String
        var categoryID: String
        var taskID: String?
        var isUrgent: Bool
    }

    private func buildPlans(for tasks: [TaskItem], settings: SettingsStore) -> [Plan] {
        let now = Date()
        var plans: [Plan] = []

        for task in tasks where task.remindersEnabled {
            let taskID = task.uid.uuidString

            // A snooze silences everything else for this task until it runs out.
            if let snoozedUntil = task.snoozedUntil, snoozedUntil > now {
                plans.append(Plan(
                    id: "\(taskID)-snooze",
                    date: snoozedUntil,
                    title: "Back to: \(task.displayTitle)",
                    body: task.dueDate.map { "Due \(Self.relativeString(for: $0))." }
                        ?? "You asked me to bring this back up.",
                    categoryID: Self.categoryID,
                    taskID: taskID,
                    isUrgent: task.isOverdue
                ))
                continue
            }

            guard let due = task.dueDate else { continue }

            // Heads-up ahead of the deadline.
            if task.leadMinutes > 0 {
                let leadDate = due.addingTimeInterval(-Double(task.leadMinutes) * 60)
                if leadDate > now {
                    plans.append(Plan(
                        id: "\(taskID)-lead",
                        date: leadDate,
                        title: "Coming up: \(task.displayTitle)",
                        body: "Due \(Self.relativeString(for: due)).",
                        categoryID: Self.categoryID,
                        taskID: taskID,
                        isUrgent: false
                    ))
                }
            }

            // The deadline itself.
            if due > now {
                plans.append(Plan(
                    id: "\(taskID)-due",
                    date: due,
                    title: "Due now: \(task.displayTitle)",
                    body: task.notes.isEmpty ? "This is due right now." : task.notes,
                    categoryID: Self.categoryID,
                    taskID: taskID,
                    isUrgent: task.priority == .high
                ))
            }

            // Keep nudging after it slips.
            if task.nagWhenOverdue && settings.nagRepeats > 0 {
                let interval = Double(max(1, settings.nagIntervalHours)) * 3600
                for step in 1...settings.nagRepeats {
                    let nagDate = due.addingTimeInterval(interval * Double(step))
                    guard nagDate > now else { continue }
                    plans.append(Plan(
                        id: "\(taskID)-nag-\(step)",
                        date: nagDate,
                        title: "Still open: \(task.displayTitle)",
                        body: "This was due \(Self.relativeString(for: due)). Knock it out?",
                        categoryID: Self.categoryID,
                        taskID: taskID,
                        isUrgent: false
                    ))
                }
            }
        }

        return plans
    }

    /// Calendar events the user hasn't imported. These get a single heads-up and
    /// no action buttons — an event isn't something you tick off here.
    private func buildEventPlans(excluding importedIDs: Set<String>, settings: SettingsStore) -> [Plan] {
        let now = Date()
        let lead = Double(max(0, settings.eventLeadMinutes)) * 60

        return CalendarBridge.shared.events
            // All-day entries (holidays, birthdays) would just be noise, and a
            // calendar full of them would eat the pending-notification budget
            // that the actual task reminders need.
            .filter { !$0.isAllDay && $0.start > now && !importedIDs.contains($0.id) }
            .prefix(12)
            .map { event in
                Plan(
                    id: "event-\(event.id)",
                    date: event.start.addingTimeInterval(-lead),
                    title: event.title,
                    body: "\(event.timeLabel) · \(event.calendarName)",
                    categoryID: Self.digestCategoryID,
                    taskID: nil,
                    isUrgent: false
                )
            }
    }

    /// Applies quiet hours, drops anything in the past, and keeps only what iOS
    /// will actually hold on to.
    private func finalise(_ plans: [Plan], settings: SettingsStore) -> [Plan] {
        let now = Date()
        return plans
            .map { plan in
                var shifted = plan
                shifted.date = settings.shiftOutOfQuietHours(plan.date)
                return shifted
            }
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(pendingBudget)
            .map { $0 }
    }

    /// A single repeating notification that sums up the day. Its text is baked in
    /// when it's scheduled, so it's refreshed every time the schedule is rebuilt.
    private func scheduleDailyDigest(openTasks: [TaskItem], settings: SettingsStore) {
        let content = UNMutableNotificationContent()
        content.title = "Today's plan"
        content.body = Self.digestBody(for: openTasks)
        content.sound = .default
        content.categoryIdentifier = Self.digestCategoryID

        var components = DateComponents()
        components.hour = settings.digestHour
        components.minute = settings.digestMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(
            identifier: Self.digestRequestID,
            content: content,
            trigger: trigger
        ))
    }

    static func digestBody(for openTasks: [TaskItem]) -> String {
        guard !openTasks.isEmpty else { return "Nothing on your list. Enjoy it." }

        let calendar = Calendar.current
        let now = Date()
        let overdue = openTasks.filter(\.isOverdue).count
        let dueToday = openTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDateInToday(due) && due >= now
        }.count

        var parts: [String] = []
        if overdue > 0 { parts.append("\(overdue) overdue") }
        if dueToday > 0 { parts.append("\(dueToday) due today") }

        guard !parts.isEmpty else {
            return "\(openTasks.count) open, nothing due today. Good place to get ahead."
        }
        return parts.joined(separator: " and ") + "."
    }

    static func relativeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
