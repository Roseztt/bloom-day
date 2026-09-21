#if DEBUG
import EventKit
import Foundation

/// Debug-only: puts a handful of events into a dedicated local calendar so the
/// Apple Calendar integration can be exercised without hand-entering events.
///
/// Guarded three ways — compiled out of Release entirely, only runs when the
/// `-seedDemoEvents YES` launch argument is passed, and only ever writes to its
/// own "Bloom Day Demo" calendar, never to the user's real ones.
enum DemoCalendar {
    private static let calendarTitle = "Bloom Day Demo"

    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "seedDemoEvents")
    }

    @MainActor
    static func seedIfRequested() async {
        guard isRequested else { return }

        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return }

        // Don't pile up duplicates across launches.
        let existing = store.calendars(for: .event).first { $0.title == calendarTitle }
        if let existing {
            let predicate = store.predicateForEvents(
                withStart: Date().addingTimeInterval(-86_400 * 30),
                end: Date().addingTimeInterval(86_400 * 30),
                calendars: [existing]
            )
            guard store.events(matching: predicate).isEmpty else { return }
        }

        let calendar: EKCalendar
        if let existing {
            calendar = existing
        } else {
            guard let local = store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first
            else { return }
            calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = calendarTitle
            calendar.source = local
            try? store.saveCalendar(calendar, commit: true)
        }

        let now = Date()
        let samples: [(String, Double, Int, String?)] = [
            ("Bio lecture", 2, 90, "Mugar 201"),
            ("Advisor meeting", 5, 30, nil),
            ("Study group", 26, 120, "Library"),
            ("Dentist", 49, 45, nil)
        ]

        for (title, hoursOut, minutes, location) in samples {
            let event = EKEvent(eventStore: store)
            event.title = title
            event.startDate = now.addingTimeInterval(hoursOut * 3600)
            event.endDate = event.startDate.addingTimeInterval(Double(minutes) * 60)
            event.location = location
            event.calendar = calendar
            try? store.save(event, span: .thisEvent, commit: false)
        }
        try? store.commit()
    }
}
#endif
