#if DEBUG
import Foundation

/// Debug-only scaffolding for screenshots and manual testing.
///
/// Launch with `-seedDemoData YES` (optionally `-startTab 1`) to get a populated
/// app. Compiled out of Release builds entirely, so nothing here reaches the phone
/// when the app is archived.
enum DemoData {
    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "seedDemoData")
    }

    /// Tab index to open on, for capturing a specific screen.
    static var startTab: Int {
        UserDefaults.standard.integer(forKey: "startTab")
    }

    @MainActor
    static func seedIfRequested() {
        guard isRequested else { return }

        let controller = DataController.shared
        guard controller.allTasks().isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()

        func at(_ days: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // Today's tasks hang off the current clock so the demo always shows a
        // believable mix rather than everything being overdue.
        func hours(_ delta: Double) -> Date {
            now.addingTimeInterval(delta * 3600)
        }

        let biology = TaskItem(
            title: "Finish biology notes",
            notes: "Chapters 7 and 8",
            dueDate: hours(-4),
            category: .school,
            estimatedMinutes: 90
        )
        biology.completedAt = hours(-4.5)

        let reading = TaskItem(
            title: "Read for 20 minutes",
            dueDate: hours(-1.5),
            category: .personal,
            estimatedMinutes: 20
        )
        reading.completedAt = hours(-1.8)

        let open: [TaskItem] = [
            biology,
            reading,
            TaskItem(
                title: "Workout (30 min)",
                dueDate: hours(1.5),
                category: .personal,
                estimatedMinutes: 30
            ),
            TaskItem(
                title: "Work on project",
                dueDate: hours(3.5),
                category: .work,
                estimatedMinutes: 60
            ),
            TaskItem(
                title: "Plan tomorrow",
                dueDate: hours(6),
                category: .personal,
                estimatedMinutes: 15
            ),
            TaskItem(
                title: "Submit reimbursement form",
                notes: "Receipts are in Downloads",
                dueDate: at(-1, hour: 17),
                priority: .high,
                category: .work,
                estimatedMinutes: 20
            ),
            TaskItem(
                title: "English essay outline",
                dueDate: at(2, hour: 10),
                category: .school,
                estimatedMinutes: 60
            ),
            TaskItem(
                title: "Chemistry lab report",
                dueDate: at(6, hour: 14),
                priority: .high,
                category: .school,
                estimatedMinutes: 120
            ),
            TaskItem(
                title: "Design club poster",
                dueDate: at(8, hour: 17),
                category: .personal,
                estimatedMinutes: 60
            ),
            TaskItem(
                title: "Look into summer internships",
                category: .work
            )
        ]

        // One task mid-flight so the "In Progress" badge shows up.
        open[2].startedAt = now

        // A completion history so the streak, weekly rates and chart have
        // something real to draw.
        let completions: [(String, TaskCategory, Int, Int, Bool)] = [
            ("Pay rent", .personal, 0, 20, true),
            ("Grocery run", .personal, 0, 45, true),
            ("Reply to housing office", .school, 1, 15, true),
            ("Return package", .personal, 1, 30, false),
            ("Reading for seminar", .school, 2, 60, true),
            ("Call home", .personal, 3, 30, true),
            ("Update résumé", .work, 4, 90, true),
            ("Fix bike tire", .personal, 4, 45, false),
            ("Organize study materials", .school, 5, 30, true),
            ("Register for classes", .school, 6, 20, true),
            ("Clean my desk", .personal, 6, 20, true),
            ("Draft lab intro", .school, 9, 60, true)
        ]

        for (title, category, daysAgo, minutes, onTime) in completions {
            let due = at(-daysAgo, hour: 18)
            let task = TaskItem(
                title: title,
                dueDate: due,
                category: category,
                estimatedMinutes: minutes
            )
            task.completedAt = onTime
                ? due.addingTimeInterval(-3600)
                : due.addingTimeInterval(7200)
            controller.context.insert(task)
        }

        open.forEach { controller.context.insert($0) }

        // Give a couple of tasks a checklist so the steps UI has something in it.
        func addSteps(_ task: TaskItem, _ titles: [String], doneThrough: Int) {
            var made: [TaskStep] = []
            for (index, title) in titles.enumerated() {
                let step = TaskStep(title: title, order: index)
                step.isDone = index < doneThrough
                step.completedAt = step.isDone ? now : nil
                step.task = task
                controller.context.insert(step)
                made.append(step)
            }
            task.steps = made
        }

        addSteps(open[3], [
            "Re-read the brief",
            "Sketch the structure",
            "Write the first section",
            "Pull in the references"
        ], doneThrough: 2)

        addSteps(open[7], [
            "Collect the raw data",
            "Plot the results",
            "Write up the method",
            "Proofread",
            "Export as PDF"
        ], doneThrough: 1)

        let goals = [
            Goal(title: "Keep a consistent study routine", symbol: "book.fill", status: .inProgress),
            Goal(title: "Read 4 books this month", symbol: "book.fill", targetCount: 4, currentCount: 2),
            Goal(title: "Stay active & healthy", symbol: "figure.walk", status: .onTrack)
        ]
        goals.forEach { controller.context.insert($0) }

        controller.save()
    }
}
#endif
