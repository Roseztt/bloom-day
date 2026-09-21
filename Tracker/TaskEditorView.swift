import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// `nil` means we're creating a new task.
    let task: TaskItem?
    /// The day the user was looking at when they tapped Add.
    var defaultDate: Date = Date()

    @State private var title = ""
    @State private var notes = ""
    @State private var category: TaskCategory = .personal
    @State private var hasDeadline = true
    @State private var dueDate = Date()
    @State private var estimatedMinutes = 0
    @State private var priority: Priority = .normal
    @State private var remindersEnabled = true
    @State private var leadMinutes = 30
    @State private var nagWhenOverdue = true

    private static let leadOptions = [0, 5, 15, 30, 60, 120, 1440]
    private static let durationOptions = [0, 15, 20, 30, 45, 60, 90, 120, 180]

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title, axis: .vertical)
                        .font(BloomFont.body(17, weight: .medium))
                        .lineLimit(1...3)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...5)
                }

                Section("Category") {
                    HStack(spacing: 8) {
                        ForEach(TaskCategory.allCases) { option in
                            Button {
                                withAnimation(.snappy) { category = option }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: option.symbol)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(option.label)
                                        .font(BloomFont.body(13, weight: .semibold))
                                }
                                .foregroundStyle(category == option ? .white : option.tint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(category == option ? option.tint : option.soft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Deadline") {
                    Toggle("Has a deadline", isOn: $hasDeadline.animation())

                    if hasDeadline {
                        DatePicker("Due", selection: $dueDate)
                        HStack(spacing: 8) {
                            quickPick("Tonight", date: Self.today(at: 20))
                            quickPick("Tomorrow", date: Self.daysOut(1, at: 9))
                            quickPick("Next week", date: Self.daysOut(7, at: 9))
                        }
                        .buttonStyle(.bordered)
                        .font(BloomFont.body(12, weight: .medium))
                    }
                }

                Section("How long will it take?") {
                    Picker("Rough time", selection: $estimatedMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(Self.durationLabel(minutes)).tag(minutes)
                        }
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Remind me", isOn: $remindersEnabled.animation())

                    if remindersEnabled && hasDeadline {
                        Picker("Heads-up", selection: $leadMinutes) {
                            ForEach(Self.leadOptions, id: \.self) { minutes in
                                Text(Self.leadLabel(minutes)).tag(minutes)
                            }
                        }
                        Toggle("Keep nudging if overdue", isOn: $nagWhenOverdue)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(reminderExplanation)
                }

                if let task {
                    Section {
                        Button("Delete task", role: .destructive) {
                            TaskActions.delete(task, context: context)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BloomBackground())
            .tint(Bloom.pink)
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    private func quickPick(_ label: String, date: Date) -> some View {
        Button(label) { dueDate = date }
    }

    private var reminderExplanation: String {
        guard remindersEnabled else {
            return "This task stays in your list but won't send notifications."
        }
        guard hasDeadline else {
            return "Without a deadline there's nothing to count down to — it'll only appear in the daily summary."
        }
        var line = "You'll get a nudge when it's due"
        if leadMinutes > 0 {
            line += ", a heads-up \(Self.leadLabel(leadMinutes).lowercased())"
        }
        if nagWhenOverdue {
            line += ", and follow-ups until you check it off"
        }
        return line + "."
    }

    // MARK: - Load & save

    private func loadExistingValues() {
        guard let task else {
            leadMinutes = SettingsStore.shared.defaultLeadMinutes
            dueDate = Self.defaultDueTime(on: defaultDate)
            return
        }
        title = task.title
        notes = task.notes
        category = task.category
        hasDeadline = task.dueDate != nil
        dueDate = task.dueDate ?? Self.defaultDueTime(on: defaultDate)
        estimatedMinutes = task.estimatedMinutes
        priority = task.priority
        remindersEnabled = task.remindersEnabled
        leadMinutes = task.leadMinutes
        nagWhenOverdue = task.nagWhenOverdue
    }

    private func save() {
        let target: TaskItem
        if let task {
            target = task
        } else {
            target = TaskItem()
            context.insert(target)
        }

        target.title = trimmedTitle
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.category = category
        target.dueDate = hasDeadline ? dueDate : nil
        target.estimatedMinutes = estimatedMinutes
        target.priority = priority
        target.remindersEnabled = remindersEnabled
        target.leadMinutes = leadMinutes
        target.nagWhenOverdue = nagWhenOverdue
        // Editing a task means the user is thinking about it again — drop any snooze.
        target.snoozedUntil = nil
        target.updatedAt = Date()

        try? context.save()
        NotificationManager.shared.refreshSchedule()
        dismiss()
    }

    // MARK: - Helpers

    static func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "None"
        case 1440: return "1 day before"
        case 60: return "1 hour before"
        case ..<60: return "\(minutes) min before"
        default: return "\(minutes / 60) hours before"
        }
    }

    static func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "Not sure"
        case ..<60: return "\(minutes) min"
        case 60: return "1 hour"
        case 90: return "1.5 hours"
        default: return "\(minutes / 60) hours"
        }
    }

    /// Keeps the time of day sensible when adding from a future date on the
    /// calendar: same clock time as now, but on the day the user was looking at.
    private static func defaultDueTime(on day: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return Date().addingTimeInterval(3600)
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day, matchingPolicy: .nextTime) ?? day
    }

    private static func today(at hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date(), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(3600)
    }

    private static func daysOut(_ days: Int, at hour: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day, matchingPolicy: .nextTime) ?? day
    }
}
