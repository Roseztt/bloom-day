import EventKit
import Observation
import SwiftUI

/// One Apple Calendar event, flattened into something the views can hold onto.
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let calendarName: String
    let tint: Color

    var timeLabel: String {
        if isAllDay { return "All day" }
        let from = start.formatted(date: .omitted, time: .shortened)
        let to = end.formatted(date: .omitted, time: .shortened)
        return from == to ? from : "\(from) – \(to)"
    }
}

/// Read-only bridge to Apple Calendar.
///
/// Events are fetched once into a cached window rather than queried from view
/// bodies — EventKit hits its own store on every call and the day views would
/// otherwise re-query on each redraw.
@MainActor
@Observable
final class CalendarBridge {
    static let shared = CalendarBridge()

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?

    private(set) var authorization: EKAuthorizationStatus
    private(set) var events: [CalendarEvent] = []

    private init() {
        authorization = EKEventStore.authorizationStatus(for: .event)

        // Apple Calendar can change under us while the app is open.
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    var hasAccess: Bool {
        authorization == .fullAccess
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    @discardableResult
    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        authorization = EKEventStore.authorizationStatus(for: .event)
        if granted { reload() }
        return granted
    }

    /// Refreshes the cached window. Cheap enough to call on foreground.
    func reload() {
        // Re-read the status every time rather than trusting what we saw at
        // init. The user can grant or revoke access in iOS Settings while we're
        // backgrounded, and we'd otherwise keep showing nothing until relaunch.
        authorization = EKEventStore.authorizationStatus(for: .event)

        guard hasAccess else {
            events = []
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard
            let from = calendar.date(byAdding: .day, value: -60, to: now),
            let to = calendar.date(byAdding: .day, value: 180, to: now)
        else { return }

        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        events = store.events(matching: predicate)
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled event",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location?.isEmpty == false ? event.location : nil,
                    calendarName: event.calendar?.title ?? "Calendar",
                    tint: Self.color(for: event)
                )
            }
            .sorted { $0.start < $1.start }
    }

    func events(on day: Date, excluding importedIDs: Set<String> = []) -> [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            !importedIDs.contains(event.id) && calendar.isDate(event.start, inSameDayAs: day)
        }
    }

    /// Start-of-day dates in the cached window that have at least one event.
    func daysWithEvents(excluding importedIDs: Set<String> = []) -> Set<Date> {
        let calendar = Calendar.current
        return Set(
            events
                .filter { !importedIDs.contains($0.id) }
                .map { calendar.startOfDay(for: $0.start) }
        )
    }

    /// Everything from now forward, for the import picker.
    func upcoming(excluding importedIDs: Set<String>, limit: Int = 60) -> [CalendarEvent] {
        let now = Date()
        return Array(
            events
                .filter { $0.end >= now && !importedIDs.contains($0.id) }
                .prefix(limit)
        )
    }

    private static func color(for event: EKEvent) -> Color {
        guard let cg = event.calendar?.cgColor else { return Bloom.lavender }
        return Color(cgColor: cg)
    }
}
