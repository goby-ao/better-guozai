import Charts
import SwiftData
import SwiftUI

struct ParentAnalyticsView: View {
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @Query(sort: \DailyTaskRecord.dayKey) private var allTasks: [DailyTaskRecord]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedRange: AnalyticsRange = .fourWeeks

    private let today = LocalDay(date: .now)

    private var tasks: [DailyTaskRecord] {
        guard let profileID = profiles.first?.id else { return [] }
        return allTasks.filter { $0.profileId == profileID }
    }

    var body: some View {
        let snapshot = ParentAnalyticsSnapshot(
            tasks: tasks,
            range: selectedRange,
            today: today
        )

        ScrollView {
            VStack(alignment: .leading, spacing: GuozaiSpacing.xLarge) {
                header
                rangePicker
                PeriodComparisonSection(snapshot: snapshot)
                OutcomeSummarySection(snapshot: snapshot)

                LazyVGrid(columns: chartColumns, alignment: .leading, spacing: GuozaiSpacing.xLarge) {
                    RequiredTrendSection(snapshot: snapshot)
                    DomainComparisonSection(snapshot: snapshot)
                }

                RecentDomainMatrix(snapshot: snapshot)
                methodology
            }
            .frame(maxWidth: GuozaiLayout.readableContentWidth, alignment: .leading)
            .padding(.horizontal, horizontalSizeClass == .regular ? GuozaiSpacing.xLarge : GuozaiSpacing.large)
            .padding(.vertical, GuozaiSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(GuozaiColor.canvasWarm.ignoresSafeArea())
        .navigationTitle("成长分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chartColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: GuozaiSpacing.xLarge, alignment: .top),
                GridItem(.flexible(), spacing: GuozaiSpacing.xLarge, alignment: .top),
            ]
        }
        return [GridItem(.flexible(), alignment: .top)]
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            Text("看见自己的进步")
                .guozaiTextStyle(.pageTitle)
                .foregroundStyle(GuozaiColor.ink)
            Text("只和过去的自己比较，用记录找到更舒服的成长节奏。")
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangePicker: some View {
        Picker("分析范围", selection: $selectedRange) {
            ForEach(AnalyticsRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("选择成长分析范围")
    }

    private var methodology: some View {
        Label {
            Text("统计口径：必做趋势只看必做任务；领域图和矩阵包含全部任务。今天尚未完成的任务仍是“待完成”，不会提前记为“过去未完成”。")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(GuozaiColor.ocean)
        }
        .guozaiTextStyle(.supporting)
        .foregroundStyle(GuozaiColor.inkMuted)
        .padding(.horizontal, GuozaiSpacing.small)
    }
}

private enum AnalyticsRange: Int, CaseIterable, Identifiable {
    case week = 7
    case fourWeeks = 28
    case quarter = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: "7 天"
        case .fourWeeks: "28 天"
        case .quarter: "90 天"
        }
    }
}

private enum AnalyticsOutcome: String, CaseIterable, Identifiable {
    case completed
    case skipped
    case missed

    var id: Self { self }

    var title: String {
        switch self {
        case .completed: "完成"
        case .skipped: "跳过"
        case .missed: "过去未完成"
        }
    }

    var symbol: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.end.circle.fill"
        case .missed: "clock.badge.questionmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .completed: GuozaiColor.ocean
        case .skipped: GuozaiColor.mango
        case .missed: GuozaiColor.inkMuted
        }
    }
}

private struct ParentAnalyticsSnapshot {
    let range: AnalyticsRange
    let today: LocalDay
    let currentDays: [LocalDay]
    let previousDays: [LocalDay]
    let matrixDays: [LocalDay]
    let currentTasks: [DailyTaskRecord]
    let previousTasks: [DailyTaskRecord]

    private let allTasksByDay: [String: [DailyTaskRecord]]

    init(tasks: [DailyTaskRecord], range: AnalyticsRange, today: LocalDay) {
        self.range = range
        self.today = today
        currentDays = Self.days(endingAt: today, count: range.rawValue)
        matrixDays = Self.days(endingAt: today, count: 14)

        let calendar = Calendar.guozaiGregorian
        if
            let todayDate = today.date(calendar: calendar),
            let previousEndDate = calendar.date(byAdding: .day, value: -range.rawValue, to: todayDate)
        {
            previousDays = Self.days(
                endingAt: LocalDay(date: previousEndDate, calendar: calendar),
                count: range.rawValue
            )
        } else {
            previousDays = []
        }

        let currentKeys = Set(currentDays.map(\.key))
        let previousKeys = Set(previousDays.map(\.key))
        currentTasks = tasks.filter { currentKeys.contains($0.dayKey) }
        previousTasks = tasks.filter { previousKeys.contains($0.dayKey) }
        allTasksByDay = Dictionary(grouping: tasks, by: \.dayKey)
    }

    var trendPoints: [RequiredTrendPoint] {
        currentDays.compactMap { day in
            let requiredTasks = tasks(on: day).filter { $0.requirement == .required }
            guard !requiredTasks.isEmpty, let date = day.date() else { return nil }
            let completed = requiredTasks.count { $0.status == .completed }
            return RequiredTrendPoint(
                day: day,
                date: date,
                completedCount: completed,
                totalCount: requiredTasks.count
            )
        }
    }

    var domainRows: [DomainOutcomeRow] {
        StoredGrowthDomain.allCases.flatMap { domain in
            AnalyticsOutcome.allCases.map { outcome in
                DomainOutcomeRow(
                    domain: domain,
                    outcome: outcome,
                    count: currentTasks.count { task in
                        task.growthDomain == domain && self.outcome(for: task) == outcome
                    }
                )
            }
        }
    }

    var currentRequiredRate: Double? { requiredRate(for: currentTasks) }
    var previousRequiredRate: Double? { requiredRate(for: previousTasks) }

    func count(for outcome: AnalyticsOutcome) -> Int {
        currentTasks.count { self.outcome(for: $0) == outcome }
    }

    func tasks(on day: LocalDay) -> [DailyTaskRecord] {
        allTasksByDay[day.key, default: []]
    }

    func matrixBreakdown(for day: LocalDay, domain: StoredGrowthDomain) -> MatrixBreakdown {
        MatrixBreakdown(
            tasks: tasks(on: day).filter { $0.growthDomain == domain },
            day: day,
            today: today
        )
    }

    private func outcome(for task: DailyTaskRecord) -> AnalyticsOutcome? {
        switch task.status {
        case .completed: .completed
        case .skipped: .skipped
        case .pending:
            LocalDay(key: task.dayKey).map { $0 < today } == true ? .missed : nil
        }
    }

    private func requiredRate(for tasks: [DailyTaskRecord]) -> Double? {
        let requiredTasks = tasks.filter { $0.requirement == .required }
        guard !requiredTasks.isEmpty else { return nil }
        return Double(requiredTasks.count { $0.status == .completed }) / Double(requiredTasks.count)
    }

    private static func days(endingAt end: LocalDay, count: Int) -> [LocalDay] {
        let calendar = Calendar.guozaiGregorian
        guard let endDate = end.date(calendar: calendar) else { return [] }
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: endDate).map {
                LocalDay(date: $0, calendar: calendar)
            }
        }
    }
}

private struct PeriodComparisonSection: View {
    let snapshot: ParentAnalyticsSnapshot

    var body: some View {
        PaperSection(
            "和上一个周期比一比",
            subtitle: "同样是 \(snapshot.range.title)，不和别人比。",
            systemImage: "arrow.left.and.right.circle.fill"
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: GuozaiSpacing.xLarge) {
                    rateBlock(title: "本周期", rate: snapshot.currentRequiredRate)
                    Image(systemName: "arrow.right")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(GuozaiColor.line)
                        .accessibilityHidden(true)
                    rateBlock(title: "上一周期", rate: snapshot.previousRequiredRate)
                    Spacer(minLength: 0)
                    comparisonMessage
                        .frame(maxWidth: 360, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
                    HStack(spacing: GuozaiSpacing.xLarge) {
                        rateBlock(title: "本周期", rate: snapshot.currentRequiredRate)
                        rateBlock(title: "上一周期", rate: snapshot.previousRequiredRate)
                    }
                    comparisonMessage
                }
            }
        }
    }

    private func rateBlock(title: String, rate: Double?) -> some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
            Text(title)
                .guozaiTextStyle(.supporting)
                .foregroundStyle(GuozaiColor.inkMuted)
            Text(rate.map(Self.percentText) ?? "—")
                .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(GuozaiColor.oceanDeep)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)必做完成率\(rate.map(Self.percentText) ?? "暂无数据")")
    }

    private var comparisonMessage: some View {
        Label {
            Text(message)
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: messageSymbol)
                .font(.title2)
                .foregroundStyle(GuozaiColor.mango)
        }
    }

    private var message: String {
        guard let current = snapshot.currentRequiredRate else {
            return "这段时间还没有必做记录，新的起点随时都可以开始。"
        }
        guard let previous = snapshot.previousRequiredRate else {
            return "这是第一段可比较的记录，先把自己的节奏留下来。"
        }

        let delta = current - previous
        if delta >= 0.005 {
            return "比上一周期多 \(Self.pointsText(delta)) 个百分点，稳定的小步正在积累。"
        }
        if delta <= -0.005 {
            return "比上一周期少 \(Self.pointsText(abs(delta))) 个百分点，可以一起看看计划是否需要放松一点。"
        }
        return "和上一周期基本持平，自己的节奏保持得很稳。"
    }

    private var messageSymbol: String {
        guard let current = snapshot.currentRequiredRate, let previous = snapshot.previousRequiredRate else {
            return "sparkles"
        }
        return current >= previous ? "sun.max.fill" : "leaf.fill"
    }

    private static func percentText(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func pointsText(_ value: Double) -> String {
        (value * 100).formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct OutcomeSummarySection: View {
    let snapshot: ParentAnalyticsSnapshot

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: GuozaiSpacing.medium)]

    var body: some View {
        PaperSection(
            "这段时间的任务去向",
            subtitle: "三种结果分开呈现；今天仍在进行的待办不提前归类。",
            systemImage: "list.bullet.clipboard.fill"
        ) {
            LazyVGrid(columns: columns, spacing: GuozaiSpacing.medium) {
                ForEach(AnalyticsOutcome.allCases) { outcome in
                    OutcomeMetric(outcome: outcome, count: snapshot.count(for: outcome))
                }
            }
        }
    }
}

private struct OutcomeMetric: View {
    let outcome: AnalyticsOutcome
    let count: Int

    var body: some View {
        HStack(spacing: GuozaiSpacing.medium) {
            Image(systemName: outcome.symbol)
                .font(.title2)
                .foregroundStyle(outcome.color)
                .frame(width: 42, height: 42)
                .background(outcome.color.opacity(0.12), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))

            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                Text("\(count)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(GuozaiColor.ink)
                Text(outcome.title)
                    .guozaiTextStyle(.supporting)
                    .foregroundStyle(GuozaiColor.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(GuozaiSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(outcome.color.opacity(0.07), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outcome.title) \(count) 项")
    }
}

private struct RequiredTrendSection: View {
    let snapshot: ParentAnalyticsSnapshot

    var body: some View {
        PaperSection(
            "每日必做完成趋势",
            subtitle: "没有安排必做任务的日期不纳入折线。",
            systemImage: "chart.xyaxis.line"
        ) {
            if snapshot.trendPoints.isEmpty {
                AnalyticsEmptyState(text: "这个范围里还没有必做记录。")
            } else {
                Chart(snapshot.trendPoints) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("完成率", point.rate)
                    )
                    .foregroundStyle(GuozaiColor.ocean)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("完成率", point.rate)
                    )
                    .foregroundStyle(GuozaiColor.mango)
                    .symbolSize(snapshot.range == .quarter ? 22 : 44)
                    .accessibilityLabel(point.accessibilityLabel)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine().foregroundStyle(GuozaiColor.line.opacity(0.55))
                        AxisValueLabel {
                            if let fraction = value.as(Double.self) {
                                Text(fraction, format: .percent.precision(.fractionLength(0)))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                        AxisGridLine().foregroundStyle(GuozaiColor.line.opacity(0.25))
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(minHeight: 300)
                .accessibilityLabel("每日必做完成率折线图")
            }
        }
    }

    private var xAxisStride: Int {
        switch snapshot.range {
        case .week: 1
        case .fourWeeks: 7
        case .quarter: 14
        }
    }
}

private struct RequiredTrendPoint: Identifiable {
    let day: LocalDay
    let date: Date
    let completedCount: Int
    let totalCount: Int

    var id: String { day.key }
    var rate: Double { Double(completedCount) / Double(totalCount) }
    var accessibilityLabel: String {
        "\(day.month) 月 \(day.day) 日，必做完成 \(completedCount) 项，共 \(totalCount) 项，完成率 \(rate.formatted(.percent.precision(.fractionLength(0))))"
    }
}

private struct DomainComparisonSection: View {
    let snapshot: ParentAnalyticsSnapshot

    var body: some View {
        PaperSection(
            "六个成长领域",
            subtitle: "条形越长，说明这个领域留下的任务记录越多。",
            systemImage: "chart.bar.xaxis"
        ) {
            if snapshot.currentTasks.isEmpty {
                AnalyticsEmptyState(text: "这个范围里还没有领域记录。")
            } else {
                Chart(snapshot.domainRows) { row in
                    BarMark(
                        x: .value("任务数", row.count),
                        y: .value("成长领域", row.domain.title)
                    )
                    .foregroundStyle(by: .value("状态", row.outcome.title))
                    .accessibilityLabel(row.accessibilityLabel)
                }
                .chartForegroundStyleScale([
                    AnalyticsOutcome.completed.title: AnalyticsOutcome.completed.color,
                    AnalyticsOutcome.skipped.title: AnalyticsOutcome.skipped.color,
                    AnalyticsOutcome.missed.title: AnalyticsOutcome.missed.color,
                ])
                .chartYScale(domain: StoredGrowthDomain.allCases.map(\.title))
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) {
                        AxisGridLine().foregroundStyle(GuozaiColor.line.opacity(0.45))
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: GuozaiSpacing.medium)
                .frame(minHeight: 360)
                .accessibilityLabel("六个成长领域任务结果横向条形图")
            }
        }
    }
}

private struct DomainOutcomeRow: Identifiable {
    let domain: StoredGrowthDomain
    let outcome: AnalyticsOutcome
    let count: Int

    var id: String { "\(domain.rawValue)|\(outcome.rawValue)" }
    var accessibilityLabel: String { "\(domain.title)，\(outcome.title) \(count) 项" }
}

private struct RecentDomainMatrix: View {
    let snapshot: ParentAnalyticsSnapshot

    var body: some View {
        PaperSection(
            "最近 14 天成长矩阵",
            subtitle: "每一行是一天，每一列是一个成长领域；一格内可同时看到不同任务结果。",
            systemImage: "square.grid.3x3.fill"
        ) {
            matrixLegend

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
                    headerRow
                    Divider().overlay(GuozaiColor.line)

                    ForEach(snapshot.matrixDays, id: \.key) { day in
                        HStack(spacing: GuozaiSpacing.small) {
                            Text(dayLabel(day))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(day == snapshot.today ? GuozaiColor.oceanDeep : GuozaiColor.inkMuted)
                                .frame(width: 72, alignment: .leading)

                            ForEach(StoredGrowthDomain.allCases) { domain in
                                MatrixCell(
                                    domain: domain,
                                    day: day,
                                    breakdown: snapshot.matrixBreakdown(for: day, domain: domain)
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, GuozaiSpacing.small)
            }
            .accessibilityLabel("最近十四天日期与成长领域矩阵")
        }
    }

    private var headerRow: some View {
        HStack(spacing: GuozaiSpacing.small) {
            Text("日期")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GuozaiColor.inkMuted)
                .frame(width: 72, alignment: .leading)

            ForEach(StoredGrowthDomain.allCases) { domain in
                VStack(spacing: GuozaiSpacing.xSmall) {
                    Image(systemName: domain.symbol)
                        .foregroundStyle(domain.themeColor)
                    Text(domain.shortTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GuozaiColor.ink)
                }
                .frame(width: 68)
                .frame(minHeight: 52)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(domain.title)
            }
        }
    }

    private var matrixLegend: some View {
        HStack(spacing: GuozaiSpacing.large) {
            MatrixLegendItem(title: "完成", color: GuozaiColor.ocean)
            MatrixLegendItem(title: "跳过", color: GuozaiColor.mango)
            MatrixLegendItem(title: "过去未完成", color: GuozaiColor.inkMuted)
            MatrixLegendItem(title: "今日待办", color: GuozaiColor.line)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dayLabel(_ day: LocalDay) -> String {
        day == snapshot.today ? "今天" : "\(day.month)/\(day.day)"
    }
}

private struct MatrixCell: View {
    let domain: StoredGrowthDomain
    let day: LocalDay
    let breakdown: MatrixBreakdown

    var body: some View {
        GeometryReader { geometry in
            if breakdown.totalCount == 0 {
                RoundedRectangle(cornerRadius: 6)
                    .fill(GuozaiColor.canvasWarm.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GuozaiColor.line.opacity(0.45), lineWidth: 1)
                    }
            } else {
                HStack(spacing: 1) {
                    segment(
                        count: breakdown.completedCount,
                        total: breakdown.totalCount,
                        availableWidth: geometry.size.width,
                        color: domain.themeColor
                    )
                    segment(
                        count: breakdown.skippedCount,
                        total: breakdown.totalCount,
                        availableWidth: geometry.size.width,
                        color: GuozaiColor.mango
                    )
                    segment(
                        count: breakdown.missedCount,
                        total: breakdown.totalCount,
                        availableWidth: geometry.size.width,
                        color: GuozaiColor.inkMuted
                    )
                    segment(
                        count: breakdown.waitingCount,
                        total: breakdown.totalCount,
                        availableWidth: geometry.size.width,
                        color: GuozaiColor.line
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: 68, height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.month) 月 \(day.day) 日，\(domain.title)，\(breakdown.accessibilitySummary)")
    }

    @ViewBuilder
    private func segment(
        count: Int,
        total: Int,
        availableWidth: CGFloat,
        color: Color
    ) -> some View {
        if count > 0 {
            color.frame(width: max(3, availableWidth * CGFloat(count) / CGFloat(total) - 1))
        }
    }
}

private struct MatrixBreakdown {
    let completedCount: Int
    let skippedCount: Int
    let missedCount: Int
    let waitingCount: Int

    init(tasks: [DailyTaskRecord], day: LocalDay, today: LocalDay) {
        completedCount = tasks.count { $0.status == .completed }
        skippedCount = tasks.count { $0.status == .skipped }
        missedCount = day < today ? tasks.count { $0.status == .pending } : 0
        waitingCount = day == today ? tasks.count { $0.status == .pending } : 0
    }

    var totalCount: Int { completedCount + skippedCount + missedCount + waitingCount }

    var accessibilitySummary: String {
        guard totalCount > 0 else { return "没有任务" }
        var parts: [String] = []
        if completedCount > 0 { parts.append("完成 \(completedCount) 项") }
        if skippedCount > 0 { parts.append("跳过 \(skippedCount) 项") }
        if missedCount > 0 { parts.append("过去未完成 \(missedCount) 项") }
        if waitingCount > 0 { parts.append("今日待办 \(waitingCount) 项") }
        return parts.joined(separator: "，")
    }
}

private struct MatrixLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
                .font(.caption.weight(.semibold))
        } icon: {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 15, height: 15)
        }
        .foregroundStyle(GuozaiColor.inkMuted)
    }
}

private struct AnalyticsEmptyState: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "sparkles")
            .guozaiTextStyle(.body)
            .foregroundStyle(GuozaiColor.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(GuozaiColor.canvasWarm.opacity(0.45), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
    }
}

private extension StoredGrowthDomain {
    var shortTitle: String {
        switch self {
        case .learning: "学习"
        case .reading: "阅读"
        case .exercise: "运动"
        case .selfCare: "自理"
        case .familyResponsibility: "家庭"
        case .exploration: "探索"
        }
    }
}
