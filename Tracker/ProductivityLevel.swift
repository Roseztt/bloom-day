import SwiftUI

/// A gentle lifetime-progress ladder based on how many tasks have been finished.
/// Every number here is derived from real completions — nothing decorative.
enum ProductivityLevel: Int, CaseIterable {
    case seedling = 0
    case sprout = 1
    case budding = 2
    case brightBloomer = 3
    case fullBloom = 4
    case radiant = 5

    var title: String {
        switch self {
        case .seedling: return "Seedling"
        case .sprout: return "Sprout"
        case .budding: return "Budding"
        case .brightBloomer: return "Bright Bloomer"
        case .fullBloom: return "In Full Bloom"
        case .radiant: return "Radiant"
        }
    }

    var symbol: String {
        switch self {
        case .seedling, .sprout: return "leaf.fill"
        case .budding: return "camera.macro"
        case .brightBloomer, .fullBloom: return "sparkles"
        case .radiant: return "sun.max.fill"
        }
    }

    /// Completed tasks needed to reach this level.
    var threshold: Int {
        switch self {
        case .seedling: return 0
        case .sprout: return 10
        case .budding: return 30
        case .brightBloomer: return 60
        case .fullBloom: return 120
        case .radiant: return 250
        }
    }

    static func level(for completed: Int) -> ProductivityLevel {
        allCases.last { completed >= $0.threshold } ?? .seedling
    }

    var next: ProductivityLevel? {
        ProductivityLevel(rawValue: rawValue + 1)
    }
}

struct LevelProgress {
    let level: ProductivityLevel
    let completed: Int

    var next: ProductivityLevel? { level.next }

    /// How far through the current level, 0...1.
    var fraction: Double {
        guard let next else { return 1 }
        let span = Double(next.threshold - level.threshold)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(completed - level.threshold) / span))
    }

    var caption: String {
        guard let next else { return "You've reached the top of the garden." }
        let remaining = max(0, next.threshold - completed)
        return remaining == 1
            ? "1 more task to \(next.title)."
            : "\(remaining) more tasks to \(next.title)."
    }

    static func from(completedCount: Int) -> LevelProgress {
        LevelProgress(level: .level(for: completedCount), completed: completedCount)
    }
}

/// An earned badge. All of these are computed from the task history rather than
/// stored, so they can't get out of step with reality.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let isUnlocked: Bool
}

enum Achievements {
    static func evaluate(tasks: [TaskItem], calendar: Calendar = .current) -> [Achievement] {
        let completed = tasks.filter { $0.completedAt != nil }
        let onTime = completed.filter { $0.completedOnTime == true }
        let early = completed.filter { task in
            guard let done = task.completedAt, let due = task.dueDate else { return false }
            return done <= due.addingTimeInterval(-3600)
        }

        let perfectDays = perfectDayRun(completed: completed, calendar: calendar)
        let streak = streakLength(completed: completed, calendar: calendar)
        let focusMinutes = completed.reduce(0) { $0 + $1.estimatedMinutes }

        return [
            Achievement(
                id: "first-bloom",
                title: "First Bloom",
                detail: "Finished your first task",
                symbol: "camera.macro",
                tint: Bloom.pink,
                isUnlocked: !completed.isEmpty
            ),
            Achievement(
                id: "on-track",
                title: "On Track",
                detail: perfectDays > 0
                    ? "Everything on time for \(perfectDays) day\(perfectDays == 1 ? "" : "s")"
                    : "Finish a full day on time",
                symbol: "checkmark.seal.fill",
                tint: Bloom.mint,
                isUnlocked: perfectDays >= 3
            ),
            Achievement(
                id: "week-warrior",
                title: "Week Warrior",
                detail: streak >= 7
                    ? "\(streak)-day streak and counting"
                    : "Reach a 7-day streak (at \(streak))",
                symbol: "flame.fill",
                tint: Bloom.peach,
                isUnlocked: streak >= 7
            ),
            Achievement(
                id: "early-bird",
                title: "Early Bird",
                detail: "\(early.count) task\(early.count == 1 ? "" : "s") done an hour early",
                symbol: "sunrise.fill",
                tint: Bloom.lavender,
                isUnlocked: early.count >= 5
            ),
            Achievement(
                id: "steady-hand",
                title: "Steady Hand",
                detail: "\(onTime.count) finished before the deadline",
                symbol: "target",
                tint: Bloom.mint,
                isUnlocked: onTime.count >= 20
            ),
            Achievement(
                id: "deep-focus",
                title: "Deep Focus",
                detail: String(format: "%.1f focus hours logged", Double(focusMinutes) / 60),
                symbol: "hourglass",
                tint: Bloom.pink,
                isUnlocked: focusMinutes >= 600
            )
        ]
    }

    /// Consecutive days, ending today, where everything completed was on time and
    /// at least one thing was completed.
    static func perfectDayRun(completed: [TaskItem], calendar: Calendar = .current) -> Int {
        var byDay: [Date: [TaskItem]] = [:]
        for task in completed {
            guard let done = task.completedAt else { continue }
            byDay[calendar.startOfDay(for: done), default: []].append(task)
        }

        var cursor = calendar.startOfDay(for: Date())
        if byDay[cursor] == nil, let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }

        var run = 0
        while let dayTasks = byDay[cursor], !dayTasks.isEmpty {
            guard dayTasks.allSatisfy({ $0.completedOnTime != false }) else { break }
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return run
    }

    /// Consecutive days ending today with at least one completion.
    static func streakLength(completed: [TaskItem], calendar: Calendar = .current) -> Int {
        let days = Set(completed.compactMap { $0.completedAt }.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
