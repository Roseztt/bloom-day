import SwiftUI

/// The date picker on Home. Collapsed it's a single week; expanded it becomes a
/// full month grid with the category legend — which is why there's no separate
/// Calendar tab any more.
struct CalendarCard: View {
    @Binding var selectedDate: Date
    /// Up to three dot colours for a given day, supplied by the host screen.
    let dots: (Date) -> [Color]

    @State private var isExpanded = false
    @State private var anchor = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 14) {
            headerRow

            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(BloomFont.body(11, weight: .medium))
                        .foregroundStyle(Bloom.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(Array(monthWeeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 0) {
                            ForEach(week, id: \.self) { dayCell($0) }
                        }
                    }
                }
                legend
            } else {
                HStack(spacing: 0) {
                    ForEach(currentWeek, id: \.self) { dayCell($0) }
                }
            }

            expandToggle
        }
        .bloomCard(padding: 16)
        .onChange(of: selectedDate) { _, newValue in
            // Keep the visible month in step when the day changes from elsewhere.
            if !calendar.isDate(newValue, equalTo: anchor, toGranularity: .month) {
                anchor = newValue
            }
        }
    }

    // MARK: - Pieces

    private var headerRow: some View {
        HStack {
            Button {
                withAnimation(.snappy) { shift(-1) }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(anchor.formatted(.dateTime.month(.wide).year()))
                .font(BloomFont.heading(17))
                .foregroundStyle(Bloom.ink)
                .contentTransition(.numericText())

            Spacer()

            Button {
                withAnimation(.snappy) { shift(1) }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Bloom.inkSoft)
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if !calendar.isDateInToday(selectedDate) {
                Button("Today") {
                    withAnimation(.snappy) {
                        selectedDate = Date()
                        anchor = Date()
                    }
                }
                .font(BloomFont.body(11, weight: .semibold))
                .foregroundStyle(Bloom.pink)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Bloom.pinkSoft, in: Capsule())
                .buttonStyle(.plain)
                .offset(x: 26)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let inMonth = !isExpanded || calendar.isDate(day, equalTo: anchor, toGranularity: .month)
        let colors = dots(day)

        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isSelected ? Bloom.pink : Color.clear)
                    .frame(width: 32, height: 32)

                if calendar.isDateInToday(day) && !isSelected {
                    Circle()
                        .strokeBorder(Bloom.pink.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Text("\(calendar.component(.day, from: day))")
                    .font(BloomFont.body(14, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (inMonth ? Bloom.ink : Bloom.inkSoft.opacity(0.4)))
            }

            HStack(spacing: 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.9) : color)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? 44 : 48)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) { selectedDate = day }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(TaskCategory.allCases) { category in
                legendDot(category.tint, category.label)
            }
            legendDot(Bloom.pink, "Overdue")
            legendDot(Bloom.inkSoft.opacity(0.55), "Event")
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(BloomFont.body(10))
                .foregroundStyle(Bloom.inkSoft)
        }
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
                anchor = selectedDate
            }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Show week" : "Show month")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .font(BloomFont.body(12, weight: .medium))
            .foregroundStyle(Bloom.inkSoft)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dates

    private func shift(_ delta: Int) {
        let unit: Calendar.Component = isExpanded ? .month : .weekOfYear
        guard let moved = calendar.date(byAdding: unit, value: delta, to: anchor) else { return }
        anchor = moved

        // Follow the selection along when scrubbing weeks, so the row that's
        // visible is always the row the rest of Home is showing.
        if !isExpanded, let movedSelection = calendar.date(byAdding: unit, value: delta, to: selectedDate) {
            selectedDate = movedSelection
        }
    }

    private var currentWeek: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthWeeks: [[Date]] {
        guard
            let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start,
            let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start
        else { return [] }

        let days = (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }
}
