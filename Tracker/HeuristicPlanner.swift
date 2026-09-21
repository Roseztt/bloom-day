import Foundation

/// The no-Apple-Intelligence path: parses the note with plain string work.
///
/// Much dumber than the on-device model, but it means the feature still does
/// something sensible on older phones, and it's what runs in the Simulator.
enum HeuristicPlanner {

    static func plan(from text: String) -> [PlannedTask] {
        let lowered = text.lowercased()
        let due = dueDate(in: lowered)
        let clauses = splitIntoClauses(text)

        guard let first = clauses.first else { return [] }

        let title = cleanTitle(first)
        let steps = clauses.dropFirst().map(cleanStep).filter { $0.count > 2 }

        return [
            PlannedTask(
                title: title.isEmpty ? text : title,
                category: category(for: lowered),
                dueDate: due,
                estimatedMinutes: 0,
                steps: Array(steps.prefix(6))
            )
        ]
    }

    // MARK: - Dates

    private static func dueDate(in text: String) -> Date {
        let calendar = Calendar.current
        let now = Date()

        func at(_ days: Int, hour: Int = 18) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        if text.contains("tonight") { return at(0, hour: 20) }
        if text.contains("today") { return at(0) }
        if text.contains("tomorrow") { return at(1) }
        if text.contains("next week") { return at(7) }
        if text.contains("next month") { return at(30) }
        if text.contains("this weekend") { return at(daysUntil(weekday: 7)) }

        // "in 3 days" / "in 2 weeks"
        if let match = text.range(of: #"in (\d+) (day|week)"#, options: .regularExpression) {
            let fragment = String(text[match])
            let number = Int(fragment.filter(\.isNumber)) ?? 1
            return at(fragment.contains("week") ? number * 7 : number)
        }

        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                        "thursday": 5, "friday": 6, "saturday": 7]
        for (name, index) in weekdays where text.contains(name) {
            return at(daysUntil(weekday: index))
        }

        // Nothing said — same default the model is told to use.
        return at(3)
    }

    /// Days from today until the next occurrence of a weekday (1 = Sunday).
    private static func daysUntil(weekday: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let delta = (weekday - today + 7) % 7
        return delta == 0 ? 7 : delta
    }

    // MARK: - Text

    private static func category(for text: String) -> TaskCategory {
        let school = ["class", "lecture", "homework", "assignment", "essay", "exam",
                      "study", "studying", "course", "professor", "lab", "quiz", "semester"]
        let work = ["meeting", "client", "boss", "deadline", "report", "invoice",
                    "presentation", "work", "project", "email the team", "standup"]

        if school.contains(where: text.contains) { return .school }
        if work.contains(where: text.contains) { return .work }
        return .personal
    }

    /// Breaks the note on the joiners people actually use in a brain dump.
    ///
    /// Case-insensitively — people capitalise "I need to" mid-sentence, and a
    /// literal match would sail straight past it.
    private static func splitIntoClauses(_ text: String) -> [String] {
        // Longest first, so "and I need to" wins over a bare "and".
        let separators = [
            " and then ", " and also ", " and i need to ", " and i have to ",
            " and i want to ", " i need to ", " i have to ", " i want to ",
            " then ", " also ", " plus ", " and ", ",", ";", ". "
        ]

        var parts = [text]
        for separator in separators {
            parts = parts.flatMap { split($0, on: separator) }
        }

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func split(_ text: String, on separator: String) -> [String] {
        var parts: [String] = []
        var remaining = Substring(text)

        while let range = remaining.range(of: separator, options: .caseInsensitive) {
            parts.append(String(remaining[..<range.lowerBound]))
            remaining = remaining[range.upperBound...]
        }
        parts.append(String(remaining))
        return parts
    }

    private static let leadIns = [
        "i want to ", "i need to ", "i have to ", "i should ", "i'd like to ",
        "i would like to ", "remind me to ", "i must ", "gotta ", "i gotta "
    ]

    private static func cleanTitle(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = result.lowercased()
        for leadIn in leadIns where lowered.hasPrefix(leadIn) {
            result = String(result.dropFirst(leadIn.count))
            break
        }
        return sentenceCased(stripTimePhrases(result))
    }

    private static func cleanStep(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = result.lowercased()
        for leadIn in leadIns where lowered.hasPrefix(leadIn) {
            result = String(result.dropFirst(leadIn.count))
            break
        }
        return sentenceCased(stripTimePhrases(result))
    }

    /// Timing belongs on the due date, not in the wording.
    private static func stripTimePhrases(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let phrases = [
            "next week", "next month", "this weekend", "tomorrow", "tonight",
            "today", "this week", "on monday", "on tuesday", "on wednesday",
            "on thursday", "on friday", "on saturday", "on sunday"
        ]

        var changed = true
        while changed {
            changed = false
            let lowered = result.lowercased()
            for phrase in phrases where lowered.hasSuffix(" " + phrase) {
                result = String(result.dropLast(phrase.count + 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
                break
            }
        }
        return result
    }

    private static func sentenceCased(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }
}
