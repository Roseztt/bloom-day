import Foundation
import Observation
import SwiftUI

/// User-tunable reminder behaviour, backed by UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let defaultLeadMinutes = "defaultLeadMinutes"
        static let nagIntervalHours = "nagIntervalHours"
        static let nagRepeats = "nagRepeats"
        static let snoozeHours = "snoozeHours"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietStartHour = "quietStartHour"
        static let quietEndHour = "quietEndHour"
        static let dailyDigestEnabled = "dailyDigestEnabled"
        static let digestHour = "digestHour"
        static let digestMinute = "digestMinute"
        static let displayName = "displayName"
        static let tagline = "tagline"
        static let appearance = "appearance"
        static let showCalendarEvents = "showCalendarEvents"
        static let eventRemindersEnabled = "eventRemindersEnabled"
        static let eventLeadMinutes = "eventLeadMinutes"
        static let feedTopics = "feedTopics"
        static let customFeeds = "customFeeds"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    /// How long before the deadline the heads-up fires, for newly created tasks.
    var defaultLeadMinutes: Int {
        didSet { defaults.set(defaultLeadMinutes, forKey: Key.defaultLeadMinutes) }
    }

    /// Gap between follow-up nudges once a task is overdue.
    var nagIntervalHours: Int {
        didSet { defaults.set(nagIntervalHours, forKey: Key.nagIntervalHours) }
    }

    /// How many follow-ups to queue per overdue task.
    var nagRepeats: Int {
        didSet { defaults.set(nagRepeats, forKey: Key.nagRepeats) }
    }

    var snoozeHours: Int {
        didSet { defaults.set(snoozeHours, forKey: Key.snoozeHours) }
    }

    var quietHoursEnabled: Bool {
        didSet { defaults.set(quietHoursEnabled, forKey: Key.quietHoursEnabled) }
    }

    var quietStartHour: Int {
        didSet { defaults.set(quietStartHour, forKey: Key.quietStartHour) }
    }

    var quietEndHour: Int {
        didSet { defaults.set(quietEndHour, forKey: Key.quietEndHour) }
    }

    var dailyDigestEnabled: Bool {
        didSet { defaults.set(dailyDigestEnabled, forKey: Key.dailyDigestEnabled) }
    }

    var digestHour: Int {
        didSet { defaults.set(digestHour, forKey: Key.digestHour) }
    }

    var digestMinute: Int {
        didSet { defaults.set(digestMinute, forKey: Key.digestMinute) }
    }

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Key.displayName) }
    }

    var tagline: String {
        didSet { defaults.set(tagline, forKey: Key.tagline) }
    }

    /// 0 follows the system, 1 forces light, 2 forces dark.
    var appearance: Int {
        didSet { defaults.set(appearance, forKey: Key.appearance) }
    }

    /// Show Apple Calendar events alongside tasks.
    var showCalendarEvents: Bool {
        didSet { defaults.set(showCalendarEvents, forKey: Key.showCalendarEvents) }
    }

    /// Send a notification before each calendar event, without importing it.
    var eventRemindersEnabled: Bool {
        didSet { defaults.set(eventRemindersEnabled, forKey: Key.eventRemindersEnabled) }
    }

    var eventLeadMinutes: Int {
        didSet { defaults.set(eventLeadMinutes, forKey: Key.eventLeadMinutes) }
    }

    /// Which news topics the Feed tab pulls.
    var feedTopics: Set<FeedTopic> {
        didSet {
            let raw = feedTopics.map(\.rawValue).sorted()
            defaults.set(raw, forKey: Key.feedTopics)
        }
    }

    /// RSS feeds the user added by URL.
    var customFeeds: [CustomFeed] {
        didSet {
            if let data = try? JSONEncoder().encode(customFeeds) {
                defaults.set(data, forKey: Key.customFeeds)
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.defaultLeadMinutes: 30,
            Key.nagIntervalHours: 3,
            Key.nagRepeats: 3,
            Key.snoozeHours: 1,
            Key.quietHoursEnabled: true,
            Key.quietStartHour: 22,
            Key.quietEndHour: 8,
            Key.dailyDigestEnabled: true,
            Key.digestHour: 9,
            Key.digestMinute: 0,
            Key.displayName: "Friend",
            Key.tagline: "Small steps make a brighter me",
            Key.appearance: 0,
            Key.showCalendarEvents: true,
            Key.eventRemindersEnabled: true,
            Key.eventLeadMinutes: 15
        ])

        defaultLeadMinutes = defaults.integer(forKey: Key.defaultLeadMinutes)
        nagIntervalHours = defaults.integer(forKey: Key.nagIntervalHours)
        nagRepeats = defaults.integer(forKey: Key.nagRepeats)
        snoozeHours = defaults.integer(forKey: Key.snoozeHours)
        quietHoursEnabled = defaults.bool(forKey: Key.quietHoursEnabled)
        quietStartHour = defaults.integer(forKey: Key.quietStartHour)
        quietEndHour = defaults.integer(forKey: Key.quietEndHour)
        dailyDigestEnabled = defaults.bool(forKey: Key.dailyDigestEnabled)
        digestHour = defaults.integer(forKey: Key.digestHour)
        digestMinute = defaults.integer(forKey: Key.digestMinute)
        displayName = defaults.string(forKey: Key.displayName) ?? "Friend"
        tagline = defaults.string(forKey: Key.tagline) ?? ""
        appearance = defaults.integer(forKey: Key.appearance)
        showCalendarEvents = defaults.bool(forKey: Key.showCalendarEvents)
        eventRemindersEnabled = defaults.bool(forKey: Key.eventRemindersEnabled)
        eventLeadMinutes = defaults.integer(forKey: Key.eventLeadMinutes)

        if let raw = defaults.stringArray(forKey: Key.feedTopics) {
            feedTopics = Set(raw.compactMap(FeedTopic.init(rawValue:)))
        } else {
            feedTopics = [.top, .science]
        }

        if let data = defaults.data(forKey: Key.customFeeds),
           let decoded = try? JSONDecoder().decode([CustomFeed].self, from: data) {
            customFeeds = decoded
        } else {
            customFeeds = []
        }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

extension SettingsStore {
    /// True when `date` falls inside the do-not-disturb window.
    func isInQuietHours(_ date: Date) -> Bool {
        guard quietHoursEnabled, quietStartHour != quietEndHour else { return false }
        let hour = Calendar.current.component(.hour, from: date)

        if quietStartHour < quietEndHour {
            return hour >= quietStartHour && hour < quietEndHour
        }
        // The window wraps past midnight, e.g. 22:00 -> 08:00.
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// Moves a reminder that would land during quiet hours to the moment they end.
    func shiftOutOfQuietHours(_ date: Date) -> Date {
        guard isInQuietHours(date) else { return date }

        let calendar = Calendar.current
        guard var wakeUp = calendar.date(
            bySettingHour: quietEndHour,
            minute: 0,
            second: 0,
            of: date,
            matchingPolicy: .nextTime
        ) else { return date }

        if wakeUp <= date {
            wakeUp = wakeUp.addingTimeInterval(86_400)
        }
        return wakeUp
    }

    var quietHoursDescription: String {
        "\(SettingsStore.hourLabel(quietStartHour)) – \(SettingsStore.hourLabel(quietEndHour))"
    }

    static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
