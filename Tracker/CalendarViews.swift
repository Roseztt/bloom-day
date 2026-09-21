import SwiftUI
import SwiftData

/// An Apple Calendar event shown alongside tasks. Deliberately lighter than
/// `TaskCard` and with no checkbox — it isn't something you complete here.
struct EventCard: View {
    let event: CalendarEvent
    var onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(event.tint)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(BloomFont.body(15, weight: .medium))
                    .foregroundStyle(Bloom.ink)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(event.timeLabel)
                    if let location = event.location {
                        Text("· \(location)")
                            .lineLimit(1)
                    }
                }
                .font(BloomFont.body(12))
                .foregroundStyle(Bloom.inkSoft)
            }

            Spacer(minLength: 4)

            Button(action: onImport) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Bloom.pink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(event.title) as a task")
        }
        .padding(12)
        .frame(minHeight: 58)
        .background(Bloom.cardSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Bloom.hairline, lineWidth: 1)
        )
    }
}

/// Pick which upcoming events to turn into tasks.
struct ImportEventsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TaskItem]

    @State private var bridge = CalendarBridge.shared
    @State private var selected: Set<String> = []

    private var importedIDs: Set<String> {
        Set(allTasks.compactMap(\.calendarEventID))
    }

    private var events: [CalendarEvent] {
        bridge.upcoming(excluding: importedIDs)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !bridge.hasAccess {
                    accessPrompt
                } else if events.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing upcoming", systemImage: "calendar")
                    } description: {
                        Text("Either your calendar is clear, or everything in it is already a task.")
                    }
                } else {
                    list
                }
            }
            .background(BloomBackground())
            .navigationTitle("Import from Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.count > 0 ? "\(selected.count)" : "")") { importSelected() }
                        .disabled(selected.isEmpty)
                }
            }
        }
        .tint(Bloom.pink)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(groupedDays, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.dayLabel(day))
                            .font(BloomFont.heading(14))
                            .foregroundStyle(Bloom.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(events.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }) { event in
                            row(event)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ event: CalendarEvent) -> some View {
        let isOn = selected.contains(event.id)
        return Button {
            withAnimation(.snappy) {
                if isOn { selected.remove(event.id) } else { selected.insert(event.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? Bloom.pink : Bloom.hairline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(BloomFont.body(15, weight: .medium))
                        .foregroundStyle(Bloom.ink)
                        .multilineTextAlignment(.leading)
                    Text(event.timeLabel)
                        .font(BloomFont.body(12))
                        .foregroundStyle(Bloom.inkSoft)
                }

                Spacer(minLength: 0)

                Circle().fill(event.tint).frame(width: 8, height: 8)
            }
            .padding(14)
            .background(Bloom.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var accessPrompt: some View {
        ContentUnavailableView {
            Label("Calendar access needed", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text(bridge.isDenied
                 ? "Calendar access is off. Turn it on in iOS Settings → Bloom Day → Calendars."
                 : "Bloom Day needs permission to read your calendar.")
        } actions: {
            if bridge.isDenied {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Allow calendar access") {
                    Task { await bridge.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var groupedDays: [Date] {
        let calendar = Calendar.current
        var seen: [Date] = []
        for event in events {
            let day = calendar.startOfDay(for: event.start)
            if !seen.contains(day) { seen.append(day) }
        }
        return seen
    }

    private func importSelected() {
        for event in events where selected.contains(event.id) {
            TaskActions.importEvent(event, context: context)
        }
        dismiss()
    }

    static func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
