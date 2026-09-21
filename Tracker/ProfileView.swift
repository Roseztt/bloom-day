import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]
    @Query private var allGoals: [Goal]

    @State private var settings = SettingsStore.shared
    @State private var isEditingProfile = false
    @State private var editingGoal: Goal?
    @State private var isAddingGoal = false
    @State private var isEditingFeed = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BloomHeader(bubble: "You're doing amazing!", pose: .favorites)

                    profileCard
                    levelCard
                    statsGrid
                    goalsCard
                    settingsCard
                    footerNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(BloomBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingProfile) { EditProfileView() }
            .sheet(isPresented: $isEditingFeed) { FeedSettingsView() }
            .sheet(isPresented: $isAddingGoal) { GoalEditorView(goal: nil) }
            .sheet(item: $editingGoal) { goal in GoalEditorView(goal: goal) }
        }
    }

    // MARK: - Cards

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Bloom.pinkSoft)
                .frame(width: 74, height: 74)
                .overlay(BunnyView(pose: .selfCare).frame(width: 60, height: 60))

            VStack(alignment: .leading, spacing: 3) {
                Text(settings.displayName.isEmpty ? "Friend" : settings.displayName)
                    .font(BloomFont.display(21))
                    .foregroundStyle(Bloom.ink)

                if !settings.tagline.isEmpty {
                    Text(settings.tagline)
                        .font(BloomFont.note(12))
                        .foregroundStyle(Bloom.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    isEditingProfile = true
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                        .font(BloomFont.body(12, weight: .semibold))
                        .foregroundStyle(Bloom.pink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Bloom.pinkSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .bloomCard()
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Productivity Level")
                    .font(BloomFont.heading(16))
                    .foregroundStyle(Bloom.ink)
                Spacer()
                Text("\(level.completed) done")
                    .font(BloomFont.body(12))
                    .foregroundStyle(Bloom.inkSoft)
            }

            HStack(spacing: 8) {
                Image(systemName: level.level.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Bloom.mint)
                Text(level.level.title)
                    .font(BloomFont.display(20))
                    .foregroundStyle(Bloom.ink)
            }

            Capsule()
                .fill(Bloom.pinkSoft)
                .frame(height: 10)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Bloom.pink)
                            .frame(width: geo.size.width * level.fraction)
                    }
                }
                .frame(height: 10)

            Text(level.caption)
                .font(BloomFont.note(12))
                .foregroundStyle(Bloom.inkSoft)
        }
        .bloomCard()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            statTile("Tasks Completed", value: "\(monthCompleted)", symbol: "checkmark.circle.fill", tint: Bloom.mint, fill: Bloom.mintSoft)
            statTile("Day Streak", value: "\(streak)", symbol: "flame.fill", tint: Bloom.pink, fill: Bloom.pinkSoft)
            statTile("Focus Hours", value: String(format: "%.1f", focusHours), symbol: "clock.fill", tint: Bloom.lavender, fill: Bloom.lavenderSoft)
            statTile("Goals in Progress", value: "\(activeGoals.filter { $0.status != .achieved }.count)", symbol: "star.fill", tint: Bloom.peach, fill: Bloom.peachSoft)
        }
    }

    private func statTile(_ title: String, value: String, symbol: String, tint: Color, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)
            Text(value)
                .font(BloomFont.display(24))
                .foregroundStyle(Bloom.ink)
                .monospacedDigit()
            Text(title)
                .font(BloomFont.body(11))
                .foregroundStyle(Bloom.inkSoft)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goals")
                    .font(BloomFont.heading(17))
                    .foregroundStyle(Bloom.ink)
                Spacer()
                Button {
                    isAddingGoal = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(BloomFont.body(12, weight: .semibold))
                        .foregroundStyle(Bloom.pink)
                }
                .buttonStyle(.plain)
            }

            if activeGoals.isEmpty {
                Text("No goals yet. Something like \"read 4 books this month\" works well.")
                    .font(BloomFont.body(13))
                    .foregroundStyle(Bloom.inkSoft)
                    .padding(.vertical, 6)
            } else {
                ForEach(activeGoals) { goal in
                    goalRow(goal)
                    if goal.uid != activeGoals.last?.uid {
                        Divider().overlay(Bloom.hairline)
                    }
                }
            }
        }
        .bloomCard()
    }

    private func goalRow(_ goal: Goal) -> some View {
        Button {
            editingGoal = goal
        } label: {
            HStack(spacing: 11) {
                Image(systemName: goal.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(goal.status.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(goal.displayTitle)
                        .font(BloomFont.body(14, weight: .medium))
                        .foregroundStyle(Bloom.ink)
                        .multilineTextAlignment(.leading)

                    if goal.isCounted {
                        Capsule()
                            .fill(Bloom.hairline)
                            .frame(height: 6)
                            .overlay(alignment: .leading) {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(goal.status.tint)
                                        .frame(width: geo.size.width * goal.progress)
                                }
                            }
                            .frame(height: 6)
                    }
                }

                Spacer(minLength: 6)

                if goal.isCounted {
                    Text(goal.trailingLabel)
                        .font(BloomFont.body(13, weight: .semibold))
                        .foregroundStyle(Bloom.ink)
                        .monospacedDigit()
                } else {
                    BloomPill(text: goal.status.label, tint: goal.status.tint, fill: goal.status.soft, size: 11)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ReminderSettingsView()
            } label: {
                settingsRow("Reminder Settings", symbol: "bell.fill", tint: Bloom.pink)
            }
            Divider().overlay(Bloom.hairline)

            NavigationLink {
                SyncSettingsView()
            } label: {
                settingsRow("Sync", symbol: "arrow.triangle.2.circlepath", tint: Bloom.lavender)
            }
            Divider().overlay(Bloom.hairline)

            NavigationLink {
                CategoriesView()
            } label: {
                settingsRow("Task Categories", symbol: "square.stack.fill", tint: Bloom.lavender)
            }
            Divider().overlay(Bloom.hairline)

            NavigationLink {
                AppearanceView()
            } label: {
                settingsRow("Themes & Appearance", symbol: "paintpalette.fill", tint: Bloom.mint)
            }
            Divider().overlay(Bloom.hairline)

            Button {
                isEditingFeed = true
            } label: {
                settingsRow("News Feed", symbol: "newspaper.fill", tint: Bloom.peach)
            }
        }
        .buttonStyle(.plain)
        .bloomCard(padding: 4)
    }

    private func settingsRow(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(title)
                .font(BloomFont.body(15))
                .foregroundStyle(Bloom.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Bloom.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private var footerNote: some View {
        HStack(spacing: 12) {
            Text("A kinder, more productive you is always possible")
                .font(BloomFont.note(14))
                .foregroundStyle(Bloom.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            BunnyView(pose: .coffeeBreak)
                .frame(width: 52, height: 52)
        }
        .bloomCard(padding: 16, fill: Bloom.cream)
    }

    // MARK: - Numbers

    private var completedTasks: [TaskItem] { allTasks.filter { $0.completedAt != nil } }

    private var activeGoals: [Goal] {
        allGoals.filter { !$0.isArchived }.sorted { $0.createdAt < $1.createdAt }
    }

    private var level: LevelProgress {
        LevelProgress.from(completedCount: completedTasks.count)
    }

    private var monthCompleted: Int {
        completedTasks.filter { calendar.isDate($0.completedAt!, equalTo: Date(), toGranularity: .month) }.count
    }

    private var streak: Int {
        Achievements.streakLength(completed: completedTasks, calendar: calendar)
    }

    private var focusHours: Double {
        let minutes = completedTasks
            .filter { calendar.isDate($0.completedAt!, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.estimatedMinutes }
        return Double(minutes) / 60
    }
}
