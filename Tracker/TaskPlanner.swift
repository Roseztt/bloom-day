import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A task the planner proposes. Nothing is saved until the user confirms.
struct PlannedTask: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var category: TaskCategory
    var dueDate: Date?
    var estimatedMinutes: Int
    var steps: [String]
}

/// Which path actually produced the last result. Surfaced in the UI so the
/// privacy note is accurate and a silent model failure can't masquerade as
/// "handled by Apple Intelligence".
enum PlannerEngine: Equatable {
    case onDevice
    case fallback(reason: String?)
}

enum PlannerAvailability: Equatable {
    case ready
    /// On-device model can't run; we fall back to plain text parsing.
    case fallback(String)
}

/// Turns "I want to make a cake next week, I need flour and to watch a baking
/// video" into a task with steps.
///
/// Uses Apple's on-device model where it exists — nothing leaves the phone,
/// there's no API key and no cost — and falls back to a plain-language parser
/// everywhere else so the feature still does something useful.
@MainActor
enum TaskPlanner {

    private(set) static var lastEngine: PlannerEngine = .fallback(reason: nil)

    static var availability: PlannerAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .fallback("This iPhone doesn't support Apple Intelligence, so I'll read your note myself.")
                case .appleIntelligenceNotEnabled:
                    return .fallback("Turn on Apple Intelligence in iOS Settings for smarter results. Until then I'll read your note myself.")
                case .modelNotReady:
                    return .fallback("Apple Intelligence is still downloading. I'll read your note myself for now.")
                @unknown default:
                    return .fallback("The on-device model isn't available, so I'll read your note myself.")
                }
            @unknown default:
                return .fallback("The on-device model isn't available, so I'll read your note myself.")
            }
        }
        #endif
        return .fallback("Smart planning needs iOS 26. I'll read your note myself instead.")
    }

    static func plan(from text: String) async -> [PlannedTask] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .ready = availability {
            let outcome = await modelPlan(from: trimmed)
            if !outcome.tasks.isEmpty {
                lastEngine = .onDevice
                return outcome.tasks
            }
            lastEngine = .fallback(reason: outcome.error ?? "the model returned nothing usable")
        } else if case .fallback(let reason) = availability {
            lastEngine = .fallback(reason: reason)
        }
        #else
        lastEngine = .fallback(reason: nil)
        #endif

        return HeuristicPlanner.plan(from: trimmed)
    }
}

// MARK: - On-device model

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable(description: "A single task to add to a to-do list, broken into steps")
private struct GeneratedTask {
    @Guide(description: "Short imperative title, under 60 characters, e.g. 'Bake a birthday cake'")
    var title: String

    @Guide(description: "Exactly one of: school, personal, work")
    var category: String

    @Guide(description: "Whole days from today until it is due. 0 means today, 1 tomorrow, 7 a week away.")
    var daysFromToday: Int

    @Guide(description: "Hour of the day it is due, 0 to 23. Use 18 if the person didn't say.")
    var hour: Int

    @Guide(description: "Rough minutes the whole task will take, between 5 and 480")
    var estimatedMinutes: Int

    @Guide(description: "The smaller steps, in the order they should be done. Between 2 and 6 short phrases.")
    var steps: [String]
}

@available(iOS 26.0, *)
@Generable(description: "The tasks extracted from what the person wrote")
private struct GeneratedPlan {
    @Guide(description: "One task per distinct goal. Usually just one, with the details as its steps.")
    var tasks: [GeneratedTask]
}

@available(iOS 26.0, *)
private extension TaskPlanner {
    static let instructions = """
        You turn a person's note into to-do list items for a personal planner app.

        Rules:
        - Prefer ONE task with several steps over many separate tasks. Only split \
        into separate tasks when the note clearly describes unrelated goals.
        - The title is the outcome the person wants. The things they need to do \
        along the way are steps, not separate tasks.
        - Keep steps short and concrete, in the order they should happen.
        - Choose the category from the person's wording: coursework and studying \
        are school, a job or clients are work, everything else is personal.
        - If no timing is given, assume it is due in three days at 6pm.
        - Never invent details the person did not mention.
        """

    /// Returns any reason it failed so the UI can be honest about falling back
    /// rather than silently pretending the model ran.
    static func modelPlan(from text: String) async -> (tasks: [PlannedTask], error: String?) {
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Turn this into tasks: \(text)",
                generating: GeneratedPlan.self
            )
            return (response.content.tasks.map(convert), nil)
        } catch {
            // Guardrails, context overflow, model unloaded, and so on.
            return ([], error.localizedDescription)
        }
    }

    static func convert(_ generated: GeneratedTask) -> PlannedTask {
        let calendar = Calendar.current
        let day = calendar.date(
            byAdding: .day,
            value: max(0, min(generated.daysFromToday, 365)),
            to: Date()
        ) ?? Date()
        let due = calendar.date(
            bySettingHour: max(0, min(generated.hour, 23)),
            minute: 0,
            second: 0,
            of: day
        )

        let category: TaskCategory
        switch generated.category.lowercased() {
        case let value where value.contains("school"): category = .school
        case let value where value.contains("work"): category = .work
        default: category = .personal
        }

        return PlannedTask(
            title: generated.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            dueDate: due,
            estimatedMinutes: max(0, min(generated.estimatedMinutes, 480)),
            steps: generated.steps
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}

#endif
