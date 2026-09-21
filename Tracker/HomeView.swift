import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var selectedDate = Date()
    @State private var editingTask: TaskItem?
    @State private var isCreating = false
    @State private var isImporting = false
    @State private var isPlanning = false
    @State private var bridge = CalendarBridge.shared
    @State private var settings = SettingsStore.shared

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BloomHeader(
                        headline: Encouragement.headline(),
                        subhead: selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                        bubble: bubbleText,
                        pose: dayProgress >= 1 ? .completed : .home
                    )

                    CalendarCard(selectedDate: $selectedDate, dots: dots(for:))

                    progressCard
                    noteCard
                    planSection
                    eventsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(BloomBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isCreating) {
                TaskEditorView(task: nil, defaultDate: selectedDate)
            }
            .sheet(item: $editingTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $isImporting) {
                ImportEventsView()
            }
            .sheet(isPresented: $isPlanning) {
                PlanWithAIView()
            }
        }
    }

    // MARK: - Cards

    private var progressCard: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: dayProgress, lineWidth: 11)
                    .frame(width: 82, height: 82)
                Text("\(Int((dayProgress * 100).rounded()))%")
                    .font(BloomFont.display(19))
                    .foregroundStyle(Bloom.ink)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(isToday ? "Today's Progress" : "Day's Progress")
                    .font(BloomFont.heading(17))
                    .foregroundStyle(Bloom.ink)

                Text("\(completedCount) of \(dayTasks.count) task\(dayTasks.count == 1 ? "" : "s") done")
                    .font(BloomFont.body(14))
                    .foregroundStyle(Bloom.inkSoft)

                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Bloom.mint)
                    Text(progressEncouragement)
                        .font(BloomFont.note(12))
                        .foregroundStyle(Bloom.inkSoft)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .bloomCard()
    }

    private var noteCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(Encouragement.note())
                .font(BloomFont.note(15))
                .foregroundStyle(Bloom.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            SprigView()
                .frame(width: 34, height: 46)
        }
        .bloomCard(padding: 16, fill: Bloom.mintSoft)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: isToday ? "Today's Plan" : "Plan", symbol: nil) {
                HStack(spacing: 8) {
                    Button {
                        isPlanning = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Bloom.pink)
                            .frame(width: 36, height: 36)
                            .background(Bloom.pinkSoft, in: Circle())
                    }
                    .accessibilityLabel("Describe a task in your own words")

                    Button {
                        isCreating = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                            .font(BloomFont.body(14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Bloom.pink, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            if dayTasks.isEmpty {
                emptyPlan
            } else {
                ForEach(dayTasks) { task in
                    TaskCard(
                        task: task,
                        showsDate: !calendar.isDate(task.dueDate ?? selectedDate, inSameDayAs: selectedDate),
                        onToggleDone: { withAnimation(.snappy) { TaskActions.toggleDone(task, context: context) } },
                        onEdit: { editingTask = task },
                        onToggleStarted: { TaskActions.toggleStarted(task, context: context) },
                        onDelete: { withAnimation { TaskActions.delete(task, context: context) } }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        if settings.showCalendarEvents {
            VStack(alignment: .leading, spacing: 12) {
                if !dayEvents.isEmpty {
                    SectionHeader("On your calendar", symbol: "calendar")

                    ForEach(dayEvents) { event in
                        EventCard(event: event) {
                            withAnimation(.snappy) {
                                TaskActions.importEvent(event, context: context)
                            }
                        }
                    }
                }

                Button {
                    if bridge.hasAccess {
                        isImporting = true
                    } else {
                        Task {
                            await bridge.requestAccess()
                            isImporting = true
                        }
                    }
                } label: {
                    Label(
                        bridge.hasAccess ? "Import from Calendar" : "Connect Apple Calendar",
                        systemImage: "calendar.badge.plus"
                    )
                    .font(BloomFont.body(14, weight: .semibold))
                    .foregroundStyle(Bloom.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Bloom.pinkSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private var emptyPlan: some View {
        VStack(spacing: 10) {
            BunnyView(pose: .sleep)
                .frame(width: 72, height: 72)
            Text(isToday ? "Nothing planned today" : "Nothing planned for this day")
                .font(BloomFont.heading(15))
                .foregroundStyle(Bloom.ink)
            Text("Add something small and let it grow.")
                .font(BloomFont.note(13))
                .foregroundStyle(Bloom.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .bloomCard(padding: 12)
    }

    // MARK: - Data

    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    /// Tasks due on the selected day. When that day is today, anything already
    /// overdue is pulled in too so it can't quietly disappear.
    private var dayTasks: [TaskItem] {
        let onDay = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: selectedDate)
        }

        let overdue = isToday
            ? allTasks.filter { $0.isOverdue && !calendar.isDate($0.dueDate ?? .now, inSameDayAs: selectedDate) }
            : []

        return (overdue + onDay).sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            if a.isOverdue != b.isOverdue { return a.isOverdue }
            return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
        }
    }

    private var completedCount: Int {
        dayTasks.filter(\.isCompleted).count
    }

    private var dayProgress: Double {
        guard !dayTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(dayTasks.count)
    }

    /// Events on the selected day, minus any already pulled in as tasks.
    private var dayEvents: [CalendarEvent] {
        bridge.events(on: selectedDate, excluding: importedEventIDs)
    }

    private var importedEventIDs: Set<String> {
        Set(allTasks.compactMap(\.calendarEventID))
    }

    /// Up to three dots per day: overdue first, then one per task category, then
    /// a soft grey one if the day only holds calendar events.
    private func dots(for day: Date) -> [Color] {
        let dayTasks = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }

        var colors: [Color] = []
        if dayTasks.contains(where: \.isOverdue) {
            colors.append(Bloom.pink)
        }
        for category in TaskCategory.allCases
        where dayTasks.contains(where: { $0.category == category && !$0.isOverdue && !$0.isCompleted }) {
            colors.append(category.tint)
        }
        if settings.showCalendarEvents,
           !bridge.events(on: day, excluding: importedEventIDs).isEmpty {
            colors.append(Bloom.inkSoft.opacity(0.55))
        }
        return Array(colors.prefix(3))
    }

    private var progressEncouragement: String {
        switch dayProgress {
        case 1 where !dayTasks.isEmpty: return "All done. Go rest."
        case 0.6...: return "You're doing great!"
        case 0.3..<0.6: return "Nice momentum."
        case 0.001..<0.3: return "A good start counts."
        default: return dayTasks.isEmpty ? "A clear day." : "Pick the easy one first."
        }
    }

    private var bubbleText: String {
        if dayTasks.isEmpty { return "Enjoy the quiet!" }
        if dayProgress >= 1 { return "You did it!" }
        return "You got this!"
    }
}
