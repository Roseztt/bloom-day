import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Query private var allTasks: [TaskItem]

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BloomHeader(
                        headline: "Your Progress",
                        subhead: "Small steps make big changes",
                        bubble: "Looks good on you!",
                        pose: .progress
                    )

                    // A grid rather than an HStack so both cards get exactly half
                    // the width regardless of how wide their contents want to be.
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                        spacing: 14
                    ) {
                        todayCard
                        streakCard
                    }

                    weeklyCard
                    summaryCard
                    achievementsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(BloomBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Cards

    private var todayCard: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: todayProgress, lineWidth: 10)
                    .frame(width: 84, height: 84)
                VStack(spacing: 0) {
                    Text("\(Int((todayProgress * 100).rounded()))%")
                        .font(BloomFont.display(18))
                        .foregroundStyle(Bloom.ink)
                        .monospacedDigit()
                    Text("Today")
                        .font(BloomFont.body(10))
                        .foregroundStyle(Bloom.inkSoft)
                }
            }

            Text("\(todayDone) of \(todayTotal) done")
                .font(BloomFont.body(13, weight: .medium))
                .foregroundStyle(Bloom.ink)
        }
        .frame(maxWidth: .infinity)
        .bloomCard(padding: 16)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Bloom.peach)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streak) Day\(streak == 1 ? "" : "s")")
                        .font(BloomFont.display(18))
                        .foregroundStyle(Bloom.ink)
                    Text(streak > 0 ? "Keep going!" : "Start today")
                        .font(BloomFont.note(11))
                        .foregroundStyle(Bloom.inkSoft)
                }
            }

            HStack(spacing: 5) {
                ForEach(lastSevenDays, id: \.self) { day in
                    let done = completionDays.contains(day)
                    Circle()
                        .fill(done ? Bloom.mint : Bloom.hairline)
                        .frame(width: 21, height: 21)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(done ? 1 : 0)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bloomCard(padding: 16)
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Completion")
                        .font(BloomFont.heading(17))
                        .foregroundStyle(Bloom.ink)
                    Text(weekComparison)
                        .font(BloomFont.note(12))
                        .foregroundStyle(Bloom.inkSoft)
                }
                Spacer(minLength: 0)
            }

            if weekRates.allSatisfy({ $0.rate == 0 }) {
                Text("Finish something this week and it'll show up here.")
                    .font(BloomFont.body(13))
                    .foregroundStyle(Bloom.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 26)
            } else {
                Chart(weekRates) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Completion", day.rate)
                    )
                    .foregroundStyle(day.tint)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                        AxisGridLine().foregroundStyle(Bloom.hairline)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number * 100))%")
                                    .font(BloomFont.body(10))
                                    .foregroundStyle(Bloom.inkSoft)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(BloomFont.body(10))
                                    .foregroundStyle(Bloom.inkSoft)
                            }
                        }
                    }
                }
                .frame(height: 152)
            }
        }
        .bloomCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Month")
                    .font(BloomFont.heading(17))
                    .foregroundStyle(Bloom.ink)
                Spacer()
                Text("\(monthTotal) task\(monthTotal == 1 ? "" : "s")")
                    .font(BloomFont.body(12))
                    .foregroundStyle(Bloom.inkSoft)
            }

            if monthTotal == 0 {
                Text("Nothing scheduled this month yet.")
                    .font(BloomFont.body(13))
                    .foregroundStyle(Bloom.inkSoft)
                    .padding(.vertical, 18)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        Chart(monthSlices) { slice in
                            SectorMark(
                                angle: .value("Count", slice.count),
                                innerRadius: .ratio(0.64),
                                angularInset: 1.5
                            )
                            .foregroundStyle(slice.tint)
                            .cornerRadius(3)
                        }
                        .frame(width: 104, height: 104)

                        VStack(spacing: 0) {
                            Text("\(monthTotal)")
                                .font(BloomFont.display(20))
                                .foregroundStyle(Bloom.ink)
                            Text("total")
                                .font(BloomFont.body(10))
                                .foregroundStyle(Bloom.inkSoft)
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(monthSlices) { slice in
                            HStack(spacing: 8) {
                                Circle().fill(slice.tint).frame(width: 8, height: 8)
                                Text(slice.label)
                                    .font(BloomFont.body(13))
                                    .foregroundStyle(Bloom.ink)
                                Spacer(minLength: 6)
                                Text("\(slice.count)")
                                    .font(BloomFont.body(13, weight: .semibold))
                                    .foregroundStyle(Bloom.ink)
                                Text("\(Int((Double(slice.count) / Double(max(1, monthTotal)) * 100).rounded()))%")
                                    .font(BloomFont.body(11))
                                    .foregroundStyle(Bloom.inkSoft)
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            Divider().overlay(Bloom.hairline)

            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Bloom.pink)
                Text(String(format: "%.1f focus hours logged this month", monthFocusHours))
                    .font(BloomFont.body(13))
                    .foregroundStyle(Bloom.inkSoft)
                Spacer(minLength: 0)
            }
        }
        .bloomCard()
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(BloomFont.heading(17))
                .foregroundStyle(Bloom.ink)

            ForEach(achievements) { badge in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(badge.isUnlocked ? badge.tint.opacity(0.16) : Bloom.hairline.opacity(0.5))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: badge.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(badge.isUnlocked ? badge.tint : Bloom.inkSoft.opacity(0.6))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.title)
                            .font(BloomFont.body(14, weight: .semibold))
                            .foregroundStyle(badge.isUnlocked ? Bloom.ink : Bloom.inkSoft)
                        Text(badge.detail)
                            .font(BloomFont.body(11))
                            .foregroundStyle(Bloom.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if badge.isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(badge.tint)
                    }
                }
            }
        }
        .bloomCard()
    }

    // MARK: - Numbers

    private var completed: [TaskItem] { allTasks.filter { $0.completedAt != nil } }

    private var todayTasks: [TaskItem] {
        allTasks.filter { task in
            if let done = task.completedAt, calendar.isDateInToday(done) { return true }
            guard !task.isCompleted, let due = task.dueDate else { return false }
            return calendar.isDateInToday(due) || due < Date()
        }
    }

    private var todayDone: Int { todayTasks.filter(\.isCompleted).count }
    private var todayTotal: Int { todayTasks.count }

    private var todayProgress: Double {
        guard todayTotal > 0 else { return 0 }
        return Double(todayDone) / Double(todayTotal)
    }

    private var completionDays: Set<Date> {
        Set(completed.compactMap { $0.completedAt }.map { calendar.startOfDay(for: $0) })
    }

    private var streak: Int {
        Achievements.streakLength(completed: completed, calendar: calendar)
    }

    private var lastSevenDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private struct DayRate: Identifiable {
        let id: Date
        let label: String
        let rate: Double
        let tint: Color
    }

    /// Share of each day's due tasks that got finished.
    private var weekRates: [DayRate] {
        lastSevenDays.map { day in
            let due = allTasks.filter { task in
                guard let date = task.dueDate else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }
            let done = due.filter(\.isCompleted).count
            let rate = due.isEmpty ? 0 : Double(done) / Double(due.count)

            let tint: Color
            switch rate {
            case 1: tint = Bloom.mint
            case 0.5..<1: tint = Bloom.lavender
            case 0.001..<0.5: tint = Bloom.pink
            default: tint = Bloom.hairline
            }

            return DayRate(
                id: day,
                label: calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1],
                rate: rate,
                tint: tint
            )
        }
    }

    private var weekComparison: String {
        let now = Date()
        guard
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else { return "Keep blooming." }

        let thisWeek = completed.filter { $0.completedAt! >= thisWeekStart }.count
        let lastWeek = completed.filter { $0.completedAt! >= lastWeekStart && $0.completedAt! < thisWeekStart }.count

        guard lastWeek > 0 else {
            return thisWeek > 0 ? "\(thisWeek) finished so far this week." : "A fresh week to start."
        }

        let change = Int(((Double(thisWeek) - Double(lastWeek)) / Double(lastWeek) * 100).rounded())
        if change > 0 { return "Up \(change)% on last week." }
        if change < 0 { return "Down \(abs(change))% on last week — that's okay." }
        return "Steady with last week."
    }

    private struct Slice: Identifiable {
        let id: String
        let label: String
        let count: Int
        let tint: Color
    }

    private var monthTasks: [TaskItem] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, equalTo: Date(), toGranularity: .month)
        }
    }

    private var monthTotal: Int { monthTasks.count }

    private var monthSlices: [Slice] {
        let onTime = monthTasks.filter { $0.completedOnTime == true }.count
        let late = monthTasks.filter { $0.isOverdue || $0.completedOnTime == false }.count
        let pending = max(0, monthTasks.count - onTime - late)

        return [
            Slice(id: "on-time", label: "Completed on time", count: onTime, tint: Bloom.mint),
            Slice(id: "late", label: "Overdue or late", count: late, tint: Bloom.pink),
            Slice(id: "pending", label: "Still pending", count: pending, tint: Bloom.lavender)
        ].filter { $0.count > 0 }
    }

    private var monthFocusHours: Double {
        let minutes = completed
            .filter { calendar.isDate($0.completedAt!, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.estimatedMinutes }
        return Double(minutes) / 60
    }

    private var achievements: [Achievement] {
        Achievements.evaluate(tasks: allTasks, calendar: calendar)
    }
}
