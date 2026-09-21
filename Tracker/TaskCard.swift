import SwiftUI

/// One task row. Used on Home, Tasks and Calendar so they stay identical.
struct TaskCard: View {
    let task: TaskItem
    var showsDate = false

    var onToggleDone: () -> Void
    var onEdit: () -> Void
    var onToggleStarted: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            checkbox
            categoryIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(task.displayTitle)
                    .font(BloomFont.body(15, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? Bloom.inkSoft : Bloom.ink)
                    .strikethrough(task.isCompleted, color: Bloom.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !task.notes.isEmpty && !task.isCompleted {
                    Text(task.notes)
                        .font(BloomFont.body(12))
                        .foregroundStyle(Bloom.inkSoft)
                        .lineLimit(1)
                }

                metaLine
                stepProgressLine
            }

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 3) {
                BloomPill(text: task.status.label, tint: task.status.tint, fill: task.status.soft, size: 11)

                if let completedAt = task.completedAt {
                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                        .font(BloomFont.body(10))
                        .foregroundStyle(Bloom.inkSoft)
                }
            }
            .layoutPriority(-1)

            menu
        }
        .padding(12)
        .background(Bloom.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    // MARK: - Pieces

    private var checkbox: some View {
        Button(action: onToggleDone) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(task.isCompleted ? Bloom.mint : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(task.isCompleted ? Bloom.mint : Bloom.hairline, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(task.isCompleted ? 1 : 0)
                )
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")
    }

    private var categoryIcon: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(task.category.soft)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: task.category.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(task.category.tint)
            )
    }

    @ViewBuilder
    private var metaLine: some View {
        let pieces = metaPieces
        if !pieces.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                Text(pieces.joined(separator: "  |  "))
                    .font(BloomFont.body(12))
            }
            .foregroundStyle(task.isOverdue ? Bloom.pink : Bloom.inkSoft)
        }
    }

    /// A slim bar plus "2/5" when the task has a checklist.
    @ViewBuilder
    private var stepProgressLine: some View {
        if let progress = task.stepProgress {
            HStack(spacing: 6) {
                Capsule()
                    .fill(Bloom.hairline)
                    .frame(width: 52, height: 5)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(progress >= 1 ? Bloom.mint : Bloom.pink)
                            .frame(width: 52 * progress, height: 5)
                    }

                Text("\(task.completedStepCount)/\(task.stepCount)")
                    .font(BloomFont.body(11, weight: .medium))
                    .foregroundStyle(Bloom.inkSoft)
                    .monospacedDigit()
            }
            .padding(.top, 1)
        }
    }

    private var metaPieces: [String] {
        var pieces: [String] = []
        if let due = task.dueDate {
            pieces.append(showsDate ? Self.dateTimeText(due) : due.formatted(date: .omitted, time: .shortened))
        }
        if let duration = task.durationLabel {
            pieces.append(duration)
        }
        return pieces
    }

    private var menu: some View {
        Menu {
            Button(task.isCompleted ? "Mark not done" : "Mark done", systemImage: "checkmark.circle") {
                onToggleDone()
            }
            if !task.isCompleted {
                Button(task.isInProgress ? "Stop working on it" : "Start working on it",
                       systemImage: task.isInProgress ? "pause.circle" : "play.circle") {
                    onToggleStarted()
                }
            }
            Button("Open", systemImage: "chevron.right.circle", action: onEdit)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Bloom.inkSoft)
                .frame(width: 22, height: 32)
                .contentShape(Rectangle())
        }
    }

    static func dateTimeText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())) \(time)"
    }
}
