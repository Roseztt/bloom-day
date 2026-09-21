import SwiftUI
import SwiftData

/// Describe what you want to do in your own words; get tasks with steps back.
/// Nothing is saved until you've seen it and tapped Add.
struct PlanWithAIView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var drafts: [PlannedTask] = []
    @State private var isThinking = false
    @State private var hasRun = false
    @FocusState private var inputFocused: Bool

    private static let examples = [
        "I want to make a cake next week, I need to buy flour and watch a baking video",
        "Finish my chem lab report by Friday — read the notes, plot the data, write it up",
        "Sort out my room this weekend and take the donation bags out"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    input

                    if isThinking {
                        thinking
                    } else if !drafts.isEmpty {
                        results
                    } else if hasRun {
                        empty
                    } else {
                        exampleList
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BloomBackground())
            .navigationTitle("Describe it")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Bloom.pink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(drafts.isEmpty)
                }
            }
            .onAppear { inputFocused = true }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            BunnyView(pose: .ideas)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tell me what you're trying to do")
                    .font(BloomFont.heading(16))
                    .foregroundStyle(Bloom.ink)

                Text(availabilityNote)
                    .font(BloomFont.note(12))
                    .foregroundStyle(Bloom.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var availabilityNote: String {
        switch TaskPlanner.availability {
        case .ready:
            return "Handled entirely on your iPhone — nothing is sent anywhere."
        case .fallback(let reason):
            return reason
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(
                "e.g. I want to make a cake next week, I need flour and to watch a baking video",
                text: $text,
                axis: .vertical
            )
            .font(BloomFont.body(16))
            .foregroundStyle(Bloom.ink)
            .lineLimit(3...8)
            .focused($inputFocused)

            Button {
                run()
            } label: {
                Label(hasRun ? "Try again" : "Make me a task", systemImage: "sparkles")
                    .font(BloomFont.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Bloom.pink, in: Capsule())
                    .opacity(canRun ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canRun)
        }
        .bloomCard()
    }

    private var canRun: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private var thinking: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small).tint(Bloom.pink)
            Text("Working it out…")
                .font(BloomFont.body(14))
                .foregroundStyle(Bloom.inkSoft)
            Spacer(minLength: 0)
        }
        .bloomCard()
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("I couldn't make sense of that")
                .font(BloomFont.heading(15))
                .foregroundStyle(Bloom.ink)
            Text("Try saying what you want to end up with, and when.")
                .font(BloomFont.note(13))
                .foregroundStyle(Bloom.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .bloomCard()
    }

    private var exampleList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try something like")
                .font(BloomFont.body(12, weight: .semibold))
                .foregroundStyle(Bloom.inkSoft)

            ForEach(Self.examples, id: \.self) { example in
                Button {
                    text = example
                    run()
                } label: {
                    Text(example)
                        .font(BloomFont.note(13))
                        .foregroundStyle(Bloom.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Bloom.cardSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(drafts.count == 1 ? "Here's what I'd add" : "Here's what I'd add")
                .font(BloomFont.heading(16))
                .foregroundStyle(Bloom.ink)

            ForEach($drafts) { $draft in
                DraftCard(draft: $draft) {
                    drafts.removeAll { $0.id == draft.id }
                }
            }

            Text(engineNote)
                .font(BloomFont.note(12))
                .foregroundStyle(Bloom.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var engineNote: String {
        switch TaskPlanner.lastEngine {
        case .onDevice:
            return "Written by Apple Intelligence on your iPhone. Tap anything to change it before adding."
        case .fallback(let reason):
            let why = reason.map { " (\($0))" } ?? ""
            return "Read from your own words rather than the on-device model\(why). Tap anything to change it before adding."
        }
    }

    // MARK: - Actions

    private func run() {
        inputFocused = false
        isThinking = true
        hasRun = true

        Task {
            let result = await TaskPlanner.plan(from: text)
            withAnimation(.snappy) {
                drafts = result
                isThinking = false
            }
        }
    }

    private func save() {
        for draft in drafts {
            let task = TaskItem(
                title: draft.title,
                dueDate: draft.dueDate,
                category: draft.category,
                estimatedMinutes: draft.estimatedMinutes,
                leadMinutes: SettingsStore.shared.defaultLeadMinutes
            )
            context.insert(task)

            var steps: [TaskStep] = []
            for (index, title) in draft.steps.enumerated() {
                let step = TaskStep(title: title, order: index)
                step.task = task
                context.insert(step)
                steps.append(step)
            }
            task.steps = steps
        }

        try? context.save()
        NotificationManager.shared.refreshSchedule()
        dismiss()
    }
}

// MARK: - Editable preview of one proposed task

private struct DraftCard: View {
    @Binding var draft: PlannedTask
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                TextField("Title", text: $draft.title, axis: .vertical)
                    .font(BloomFont.body(16, weight: .semibold))
                    .foregroundStyle(Bloom.ink)
                    .lineLimit(1...3)

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Bloom.inkSoft.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(TaskCategory.allCases) { option in
                    Button {
                        withAnimation(.snappy) { draft.category = option }
                    } label: {
                        Text(option.label)
                            .font(BloomFont.body(12, weight: .semibold))
                            .foregroundStyle(draft.category == option ? .white : option.tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(draft.category == option ? option.tint : option.soft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            if let due = Binding($draft.dueDate) {
                DatePicker("Due", selection: due)
                    .font(BloomFont.body(14))
                    .foregroundStyle(Bloom.ink)
            }

            if !draft.steps.isEmpty {
                Divider().overlay(Bloom.hairline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(draft.steps.count) step\(draft.steps.count == 1 ? "" : "s")")
                        .font(BloomFont.body(11, weight: .semibold))
                        .foregroundStyle(Bloom.inkSoft)

                    ForEach(draft.steps.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Bloom.hairline)

                            TextField("Step", text: $draft.steps[index], axis: .vertical)
                                .font(BloomFont.body(14))
                                .foregroundStyle(Bloom.ink)
                                .lineLimit(1...3)

                            Button {
                                draft.steps.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Bloom.inkSoft.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .bloomCard()
    }
}
