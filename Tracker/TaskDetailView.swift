import SwiftUI
import SwiftData

/// What you get when you tap a task: its details, and the checklist of smaller
/// steps you work through.
struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: TaskItem

    @State private var newStep = ""
    @State private var isEditing = false
    @FocusState private var stepFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    ForEach(task.orderedSteps) { step in
                        stepRow(step)
                    }
                    .onDelete(perform: deleteSteps)
                    .onMove(perform: moveSteps)

                    addStepField
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        if task.hasSteps {
                            Text("\(task.completedStepCount) of \(task.stepCount)")
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    if task.hasSteps {
                        Text("Tick the last step and the whole task is marked done. Untick one and it reopens.")
                    } else {
                        Text("Break this into smaller pieces if it feels like a lot.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(BloomBackground())
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Bloom.pink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit details", systemImage: "pencil") { isEditing = true }
                        Button(task.isCompleted ? "Mark not done" : "Mark done", systemImage: "checkmark.circle") {
                            TaskActions.toggleDone(task, context: context)
                        }
                        Divider()
                        Button("Delete task", systemImage: "trash", role: .destructive) {
                            TaskActions.delete(task, context: context)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if task.hasSteps { EditButton() }
                }
            }
            .sheet(isPresented: $isEditing) {
                TaskEditorView(task: task, defaultDate: task.dueDate ?? Date())
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    withAnimation(.snappy) { TaskActions.toggleDone(task, context: context) }
                } label: {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(task.isCompleted ? Bloom.mint : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(task.isCompleted ? Bloom.mint : Bloom.hairline, lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(task.isCompleted ? 1 : 0)
                        )
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.displayTitle)
                        .font(BloomFont.display(21))
                        .foregroundStyle(task.isCompleted ? Bloom.inkSoft : Bloom.ink)
                        .strikethrough(task.isCompleted, color: Bloom.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(BloomFont.body(13))
                            .foregroundStyle(Bloom.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BloomPill(
                    text: task.category.label,
                    tint: task.category.tint,
                    fill: task.category.soft,
                    size: 12
                )
                BloomPill(
                    text: task.status.label,
                    tint: task.status.tint,
                    fill: task.status.soft,
                    size: 12
                )
                Spacer(minLength: 0)
            }

            if let due = task.dueDate {
                HStack(spacing: 6) {
                    Image(systemName: task.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(TaskCard.dateTimeText(due))
                    if let duration = task.durationLabel {
                        Text("· \(duration)")
                    }
                }
                .font(BloomFont.body(13))
                .foregroundStyle(task.isOverdue ? Bloom.pink : Bloom.inkSoft)
            }

            if let progress = task.stepProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(Bloom.pinkSoft)
                        .frame(height: 9)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(progress >= 1 ? Bloom.mint : Bloom.pink)
                                    .frame(width: geo.size.width * progress)
                                    .animation(.spring(duration: 0.4), value: progress)
                            }
                        }
                        .frame(height: 9)

                    Text(progress >= 1
                         ? "Every step done."
                         : "\(task.stepCount - task.completedStepCount) step\(task.stepCount - task.completedStepCount == 1 ? "" : "s") to go.")
                        .font(BloomFont.note(12))
                        .foregroundStyle(Bloom.inkSoft)
                }
            }
        }
        .padding(16)
        .background(Bloom.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Steps

    private func stepRow(_ step: TaskStep) -> some View {
        Button {
            withAnimation(.snappy) { TaskActions.toggleStep(step, context: context) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(step.isDone ? Bloom.mint : Bloom.hairline)

                Text(step.displayTitle)
                    .font(BloomFont.body(15))
                    .foregroundStyle(step.isDone ? Bloom.inkSoft : Bloom.ink)
                    .strikethrough(step.isDone, color: Bloom.inkSoft)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addStepField: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.system(size: 20))
                .foregroundStyle(Bloom.pink)

            TextField("Add a step", text: $newStep)
                .font(BloomFont.body(15))
                .focused($stepFieldFocused)
                .submitLabel(.next)
                .onSubmit(commitStep)
        }
    }

    private func commitStep() {
        let text = newStep
        newStep = ""
        withAnimation(.snappy) {
            TaskActions.addStep(text, to: task, context: context)
        }
        // Keep the field focused so several steps can be typed in a row.
        stepFieldFocused = true
    }

    private func deleteSteps(at offsets: IndexSet) {
        let ordered = task.orderedSteps
        for index in offsets where ordered.indices.contains(index) {
            TaskActions.deleteStep(ordered[index], context: context)
        }
    }

    private func moveSteps(from offsets: IndexSet, to destination: Int) {
        var ordered = task.orderedSteps
        ordered.move(fromOffsets: offsets, toOffset: destination)
        TaskActions.reorderSteps(ordered, context: context)
    }
}
