import SwiftUI
import SwiftData

// MARK: - Edit profile

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsStore.shared
    @State private var name = ""
    @State private var tagline = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What should I call you?") {
                    TextField("Name", text: $name)
                }
                Section("Your line") {
                    TextField("Small steps make a brighter me", text: $tagline, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BloomBackground())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        settings.tagline = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = settings.displayName
                tagline = settings.tagline
            }
        }
    }
}

// MARK: - Goal editor

struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: Goal?

    @State private var title = ""
    @State private var symbol = "target"
    @State private var isCounted = false
    @State private var targetCount = 4
    @State private var currentCount = 0
    @State private var status: GoalStatus = .inProgress

    private static let symbols = ["target", "book.fill", "heart.fill", "leaf.fill", "figure.walk", "moon.stars.fill", "pencil", "cup.and.saucer.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("What are you working toward?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.system(size: 17))
                                    .foregroundStyle(symbol == option ? .white : Bloom.pink)
                                    .frame(width: 44, height: 44)
                                    .background(symbol == option ? Bloom.pink : Bloom.pinkSoft, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Count it", isOn: $isCounted.animation())
                    if isCounted {
                        Stepper("Target: \(targetCount)", value: $targetCount, in: 1...100)
                        Stepper("Done so far: \(currentCount)", value: $currentCount, in: 0...max(1, targetCount))
                    } else {
                        Picker("Status", selection: $status) {
                            ForEach(GoalStatus.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    }
                } footer: {
                    Text(isCounted
                         ? "Shows as a progress bar, like 2 / 4."
                         : "Shows as a simple status you update when it changes.")
                }

                if goal != nil {
                    Section {
                        Button("Delete goal", role: .destructive) {
                            if let goal {
                                SyncEngine.shared.recordDeletion(goal.uid.uuidString)
                                context.delete(goal)
                                try? context.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BloomBackground())
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let goal else { return }
        title = goal.title
        symbol = goal.symbol
        isCounted = goal.isCounted
        targetCount = max(1, goal.targetCount)
        currentCount = goal.currentCount
        status = goal.status
    }

    private func save() {
        let target: Goal
        if let goal {
            target = goal
        } else {
            target = Goal()
            context.insert(target)
        }

        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.symbol = symbol
        target.targetCount = isCounted ? targetCount : 0
        target.currentCount = isCounted ? min(currentCount, targetCount) : 0
        target.status = isCounted
            ? (currentCount >= targetCount ? .achieved : .inProgress)
            : status
        target.updatedAt = Date()

        try? context.save()
        dismiss()
    }
}

// MARK: - Categories

struct CategoriesView: View {
    @Query private var allTasks: [TaskItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(TaskCategory.allCases) { category in
                    let tasks = allTasks.filter { $0.category == category }
                    let open = tasks.filter { !$0.isCompleted }.count

                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(category.soft)
                            .frame(width: 46, height: 46)
                            .overlay(
                                Image(systemName: category.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(category.tint)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.label)
                                .font(BloomFont.heading(16))
                                .foregroundStyle(Bloom.ink)
                            Text("\(open) open · \(tasks.count) total")
                                .font(BloomFont.body(12))
                                .foregroundStyle(Bloom.inkSoft)
                        }

                        Spacer(minLength: 0)
                    }
                    .bloomCard()
                }

                Text("Categories are fixed for now — they keep the colour coding on the calendar readable.")
                    .font(BloomFont.note(12))
                    .foregroundStyle(Bloom.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
            }
            .padding(18)
        }
        .background(BloomBackground())
        .navigationTitle("Task Categories")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @State private var settings = SettingsStore.shared

    private let options: [(Int, String, String)] = [
        (0, "Match my iPhone", "iphone"),
        (1, "Always light", "sun.max.fill"),
        (2, "Always dark", "moon.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(options, id: \.0) { value, label, symbol in
                    Button {
                        withAnimation(.snappy) { settings.appearance = value }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: symbol)
                                .font(.system(size: 16))
                                .foregroundStyle(Bloom.pink)
                                .frame(width: 28)
                            Text(label)
                                .font(BloomFont.body(16))
                                .foregroundStyle(Bloom.ink)
                            Spacer()
                            if settings.appearance == value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Bloom.pink)
                            }
                        }
                        .bloomCard()
                    }
                    .buttonStyle(.plain)
                }

                Text("The pink stays either way — dark mode just turns the background down so it's easier at night.")
                    .font(BloomFont.note(12))
                    .foregroundStyle(Bloom.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
            }
            .padding(18)
        }
        .background(BloomBackground())
        .navigationTitle("Themes & Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
