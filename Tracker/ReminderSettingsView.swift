import SwiftUI
import SwiftData
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var settings = SettingsStore.shared
    @State private var bridge = CalendarBridge.shared
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingCount = 0
    @State private var showClearConfirm = false

    private static let leadOptions = [0, 5, 15, 30, 60, 120, 1440]

    var body: some View {
        Form {
            notificationsSection
            calendarSection
            defaultsSection
            nudgeSection
            quietHoursSection
            digestSection
            dataSection
        }
        .scrollContentBackground(.hidden)
        .background(BloomBackground())
        .navigationTitle("Reminder Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Bloom.pink)
        .task { await refreshStatus() }
        .onDisappear {
            // Settings changes only reach iOS when the schedule is rebuilt.
            NotificationManager.shared.refreshSchedule()
        }
        .confirmationDialog(
            "Delete completed tasks older than 30 days?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                DataController.shared.deleteCompleted(olderThanDays: 30)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Your progress chart will lose those days.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            LabeledContent("Permission", value: statusText)

            switch authStatus {
            case .notDetermined:
                Button("Allow notifications") {
                    Task {
                        _ = await NotificationManager.shared.requestAuthorization()
                        await refreshStatus()
                        NotificationManager.shared.refreshSchedule()
                    }
                }
            case .denied:
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            default:
                LabeledContent("Scheduled", value: "\(pendingCount)")
            }
        } header: {
            Text("Notifications")
        } footer: {
            if authStatus == .denied {
                Text("Reminders are turned off in iOS Settings, so nothing will reach you until you turn them back on.")
            } else {
                Text("iOS holds a limited number of pending reminders, so the app keeps the soonest ones and refills as they fire.")
            }
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        Section {
            if bridge.hasAccess {
                Toggle("Show events alongside tasks", isOn: $settings.showCalendarEvents.animation())
                Toggle("Remind me about events", isOn: $settings.eventRemindersEnabled.animation())

                if settings.eventRemindersEnabled {
                    Picker("Heads-up before event", selection: $settings.eventLeadMinutes) {
                        ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                            Text(minutes == 0 ? "At start time" : "\(minutes) min before").tag(minutes)
                        }
                    }
                }
            } else if bridge.isDenied {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                Button("Connect Apple Calendar") {
                    Task {
                        await bridge.requestAccess()
                        NotificationManager.shared.refreshSchedule()
                    }
                }
            }
        } header: {
            Text("Apple Calendar")
        } footer: {
            if bridge.isDenied {
                Text("Calendar access is off. Turn it back on in iOS Settings → Bloom Day → Calendars.")
            } else if bridge.hasAccess {
                Text("Events stay in Apple Calendar — Bloom Day only reads them. Use Import on the Calendar tab to turn one into a task you can tick off.")
            } else {
                Text("Read your events so they show up next to your tasks. Nothing is ever written back to your calendar.")
            }
        }
    }

    private var defaultsSection: some View {
        Section {
            Picker("Heads-up before due", selection: $settings.defaultLeadMinutes) {
                ForEach(Self.leadOptions, id: \.self) { minutes in
                    Text(TaskEditorView.leadLabel(minutes)).tag(minutes)
                }
            }
        } header: {
            Text("New task defaults")
        } footer: {
            Text("Used for tasks you create from now on. Existing tasks keep their own setting.")
        }
    }

    private var nudgeSection: some View {
        Section {
            Stepper(
                "Every \(settings.nagIntervalHours) \(settings.nagIntervalHours == 1 ? "hour" : "hours")",
                value: $settings.nagIntervalHours,
                in: 1...24
            )
            Stepper(
                "\(settings.nagRepeats) \(settings.nagRepeats == 1 ? "follow-up" : "follow-ups")",
                value: $settings.nagRepeats,
                in: 0...8
            )
            Stepper(
                "Snooze for \(settings.snoozeHours) \(settings.snoozeHours == 1 ? "hour" : "hours")",
                value: $settings.snoozeHours,
                in: 1...24
            )
        } header: {
            Text("Overdue nudges")
        } footer: {
            Text(settings.nagRepeats == 0
                 ? "Follow-ups are off — an overdue task will only appear in the daily summary."
                 : "Once a task is past due I'll check in \(settings.nagRepeats) more \(settings.nagRepeats == 1 ? "time" : "times"), \(settings.nagIntervalHours) \(settings.nagIntervalHours == 1 ? "hour" : "hours") apart.")
        }
    }

    private var quietHoursSection: some View {
        Section {
            Toggle("Quiet hours", isOn: $settings.quietHoursEnabled.animation())

            if settings.quietHoursEnabled {
                Picker("From", selection: $settings.quietStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(SettingsStore.hourLabel(hour)).tag(hour)
                    }
                }
                Picker("Until", selection: $settings.quietEndHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(SettingsStore.hourLabel(hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Quiet hours")
        } footer: {
            Text(settings.quietHoursEnabled
                 ? "Reminders that would land between \(settings.quietHoursDescription) are held until quiet hours end."
                 : "Reminders can fire at any hour, including overnight.")
        }
    }

    private var digestSection: some View {
        Section {
            Toggle("Daily summary", isOn: $settings.dailyDigestEnabled.animation())

            if settings.dailyDigestEnabled {
                DatePicker("Time", selection: digestTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Daily summary")
        } footer: {
            Text("One notification each morning with what's overdue and what's due today.")
        }
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Open tasks", value: "\(allTasks.filter { !$0.isCompleted }.count)")
            LabeledContent("Completed", value: "\(allTasks.filter(\.isCompleted).count)")

            Button("Reschedule reminders now") {
                NotificationManager.shared.refreshSchedule()
                Task { await refreshStatus() }
            }

            Button("Delete completed over 30 days old", role: .destructive) {
                showClearConfirm = true
            }
        } header: {
            Text("Data")
        }
    }

    // MARK: - Helpers

    private var digestTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.digestHour,
                    minute: settings.digestMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.digestHour = parts.hour ?? 9
                settings.digestMinute = parts.minute ?? 0
            }
        )
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Blocked"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    private func refreshStatus() async {
        authStatus = await NotificationManager.shared.authorizationStatus()
        pendingCount = await NotificationManager.shared.pendingCount()
    }
}
