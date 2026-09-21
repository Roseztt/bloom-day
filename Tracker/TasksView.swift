import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var filter: TaskCategory?
    @State private var search = ""
    @State private var editingTask: TaskItem?
    @State private var isCreating = false
    @State private var isPlanning = false
    @State private var showsAllCompleted = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BloomHeader(
                        headline: "Small tasks\ncreate big dreams",
                        bubble: "You can do it!",
                        pose: .todo
                    )

                    filterRow
                    searchField
                    newTaskButton

                    if visibleTasks.isEmpty {
                        emptyState
                    } else {
                        section("Today", symbol: "heart.fill", tint: Bloom.pink, tasks: todayTasks, showsBar: true)
                        section("Upcoming", symbol: "leaf.fill", tint: Bloom.mint, tasks: upcomingTasks)
                        section("No deadline", symbol: "moon.stars.fill", tint: Bloom.lavender, tasks: somedayTasks)
                        completedSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(BloomBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isCreating) {
                TaskEditorView(task: nil, defaultDate: Date())
            }
            .sheet(item: $editingTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $isPlanning) {
                PlanWithAIView()
            }
        }
    }

    // MARK: - Controls

    private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(label: "All", symbol: nil, tint: Bloom.pink, soft: Bloom.pinkSoft, isOn: filter == nil) {
                    filter = nil
                }

                ForEach(TaskCategory.allCases) { category in
                    chip(
                        label: category.label,
                        symbol: category.symbol,
                        tint: category.tint,
                        soft: category.soft,
                        isOn: filter == category
                    ) {
                        filter = filter == category ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var newTaskButton: some View {
        HStack(spacing: 10) {
            Button {
                isCreating = true
            } label: {
                Label("New Task", systemImage: "plus")
                    .font(BloomFont.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Bloom.pink, in: Capsule())
            }

            Button {
                isPlanning = true
            } label: {
                Label("Describe it", systemImage: "sparkles")
                    .font(BloomFont.body(15, weight: .semibold))
                    .foregroundStyle(Bloom.pink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Bloom.pinkSoft, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private func chip(
        label: String,
        symbol: String?,
        tint: Color,
        soft: Color,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(BloomFont.body(14, weight: .semibold))
            }
            .foregroundStyle(isOn ? .white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isOn ? tint : soft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Bloom.inkSoft)

            TextField("Search tasks", text: $search)
                .font(BloomFont.body(15))
                .foregroundStyle(Bloom.ink)
                .autocorrectionDisabled()

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bloom.inkSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Bloom.card, in: Capsule())
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(
        _ title: String,
        symbol: String,
        tint: Color,
        tasks: [TaskItem],
        showsBar: Bool = false
    ) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title, symbol: symbol) {
                    if showsBar {
                        HStack(spacing: 8) {
                            Text("\(tasks.filter(\.isCompleted).count) of \(tasks.count) done")
                                .font(BloomFont.body(12))
                                .foregroundStyle(Bloom.inkSoft)

                            Capsule()
                                .fill(Bloom.pinkSoft)
                                .frame(width: 58, height: 7)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Bloom.pink)
                                        .frame(width: 58 * sectionProgress(tasks), height: 7)
                                }
                        }
                    } else {
                        Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                            .font(BloomFont.body(12))
                            .foregroundStyle(Bloom.inkSoft)
                    }
                }

                ForEach(tasks) { task in
                    card(for: task, showsDate: title != "Today")
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        if !completedTasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Completed", symbol: "checkmark.seal.fill") {
                    Button {
                        withAnimation(.snappy) { showsAllCompleted.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(completedTasks.count) completed")
                            Image(systemName: showsAllCompleted ? "chevron.up" : "chevron.down")
                        }
                        .font(BloomFont.body(12, weight: .medium))
                        .foregroundStyle(Bloom.inkSoft)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(showsAllCompleted ? completedTasks : Array(completedTasks.prefix(3))) { task in
                    card(for: task, showsDate: true)
                }
            }
            .padding(.top, 4)
        }
    }

    private func card(for task: TaskItem, showsDate: Bool) -> some View {
        TaskCard(
            task: task,
            showsDate: showsDate,
            onToggleDone: { withAnimation(.snappy) { TaskActions.toggleDone(task, context: context) } },
            onEdit: { editingTask = task },
            onToggleStarted: { TaskActions.toggleStarted(task, context: context) },
            onDelete: { withAnimation { TaskActions.delete(task, context: context) } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            BunnyView(pose: search.isEmpty ? .addTask : .plan)
                .frame(width: 84, height: 84)
            Text(search.isEmpty ? "No tasks here yet" : "Nothing matches")
                .font(BloomFont.heading(16))
                .foregroundStyle(Bloom.ink)
            Text(search.isEmpty
                 ? "Tap New Task and write down the first thing on your mind."
                 : "Try a different word.")
                .font(BloomFont.note(13))
                .foregroundStyle(Bloom.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .bloomCard(padding: 14)
    }

    // MARK: - Data

    private func sectionProgress(_ tasks: [TaskItem]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
    }

    private var visibleTasks: [TaskItem] {
        allTasks.filter { task in
            if let filter, task.category != filter { return false }
            guard !search.isEmpty else { return true }
            return task.title.localizedCaseInsensitiveContains(search)
                || task.notes.localizedCaseInsensitiveContains(search)
        }
    }

    /// Everything due today plus anything still open from before, completed or
    /// not — otherwise the "x of y done" counter could never move.
    private var todayTasks: [TaskItem] {
        visibleTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                if calendar.isDateInToday(due) { return true }
                return !task.isCompleted && due < Date()
            }
            .sorted { a, b in
                if a.isCompleted != b.isCompleted { return !a.isCompleted }
                return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
            }
    }

    private var upcomingTasks: [TaskItem] {
        visibleTasks
            .filter { task in
                guard !task.isCompleted, let due = task.dueDate else { return false }
                return due >= Date() && !calendar.isDateInToday(due)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var somedayTasks: [TaskItem] {
        visibleTasks
            .filter { !$0.isCompleted && $0.dueDate == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Older finished work. Today's completions already show in the Today
    /// section, so they're left out here rather than listed twice.
    private var completedTasks: [TaskItem] {
        visibleTasks
            .filter { task in
                guard task.isCompleted else { return false }
                guard let due = task.dueDate else { return true }
                return !calendar.isDateInToday(due)
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
}
