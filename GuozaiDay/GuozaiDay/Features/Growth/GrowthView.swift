import SwiftData
import SwiftUI

struct GrowthView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @Query(sort: \DailyTaskRecord.dayKey) private var allTasks: [DailyTaskRecord]
    @Query(sort: \DailyReflectionRecord.dayKey) private var reflections: [DailyReflectionRecord]

    @State private var scale: GrowthScale = .year
    @State private var didChooseInitialScale = false
    @State private var selectedDay = LocalDay(date: .now)
    @State private var selectedYear = LocalDay(date: .now).year

    private let today = LocalDay(date: .now)

    private var profileID: UUID? { profiles.first?.id }

    private var tasks: [DailyTaskRecord] {
        guard let profileID else { return [] }
        return allTasks.filter { $0.profileId == profileID }
    }

    private var tasksByDay: [String: [DailyTaskRecord]] {
        Dictionary(grouping: tasks, by: \.dayKey)
    }

    private var selectedTasks: [DailyTaskRecord] {
        tasksByDay[selectedDay.key, default: []]
    }

    private var selectedReflection: DailyReflectionRecord? {
        reflections.first { $0.profileId == profileID && $0.dayKey == selectedDay.key }
    }

    private var gardenProgress: GrowthGardenProgress {
        GrowthGardenProgress(tasks: tasks.compactMap(\.coreSnapshot))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuozaiSpacing.xLarge) {
                header
                GrowthGardenView(progress: gardenProgress)
                WeeklyHighlight(tasksByDay: tasksByDay, today: today)

                PaperSection(
                    "成长星图",
                    subtitle: "每一次认真完成，都会在这里留下一点光。",
                    systemImage: "sparkles",
                    compactDensity: true
                ) {
                    Picker("星图范围", selection: $scale) {
                        ForEach(GrowthScale.allCases) { scale in
                            Text(scale.title).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 52)
                    .accessibilityLabel("选择成长星图范围")

                    switch scale {
                    case .year:
                        YearStarMap(
                            year: $selectedYear,
                            today: today,
                            selectedDay: $selectedDay,
                            tasksByDay: tasksByDay
                        )
                    case .month:
                        MonthGrowthMap(
                            monthContaining: selectedDay,
                            today: today,
                            selectedDay: $selectedDay,
                            tasksByDay: tasksByDay
                        )
                    }
                }

                DayGrowthDetail(
                    day: selectedDay,
                    today: today,
                    tasks: selectedTasks,
                    reflection: selectedReflection
                )
            }
            .frame(maxWidth: GuozaiLayout.readableContentWidth, alignment: .leading)
            .padding(.horizontal, horizontalSizeClass == .compact ? GuozaiSpacing.medium : GuozaiSpacing.large)
            .padding(.vertical, GuozaiSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(GuozaiColor.canvasWarm.ignoresSafeArea())
        .navigationTitle("成长")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didChooseInitialScale else { return }
            scale = horizontalSizeClass == .compact ? .month : .year
            didChooseInitialScale = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            Text("成长的光")
                .guozaiTextStyle(.pageTitle)
                .foregroundStyle(GuozaiColor.ink)
            Text("不和别人比较，只看看自己又走远了多少。")
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.inkMuted)
        }
    }
}

private enum GrowthScale: String, CaseIterable, Identifiable {
    case year
    case month

    var id: Self { self }
    var title: String { self == .year ? "全年 365 颗星" : "月度六领域" }
}

private struct WeeklyHighlight: View {
    let tasksByDay: [String: [DailyTaskRecord]]
    let today: LocalDay

    private var recentDays: [LocalDay] {
        let calendar = Calendar.guozaiWeekGregorian
        guard
            let todayDate = today.date(calendar: calendar),
            let week = calendar.dateInterval(of: .weekOfYear, for: todayDate)
        else { return [today] }
        let elapsed = max(
            0,
            calendar.dateComponents([.day], from: week.start, to: todayDate).day ?? 0
        )
        return (0...elapsed).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start).map {
                LocalDay(date: $0, calendar: calendar)
            }
        }
    }

    private var recentTasks: [DailyTaskRecord] {
        recentDays.flatMap { tasksByDay[$0.key, default: []] }
    }

    private var achievedCount: Int {
        recentDays.count { day in
            StoredDailyProgress(tasks: tasksByDay[day.key, default: []]).isAchieved
        }
    }

    private var completedCount: Int {
        recentTasks.count { $0.status == .completed }
    }

    private var activeDomains: Int {
        Set(recentTasks.filter { $0.status == .completed }.map(\.growthDomainRaw)).count
    }

    var body: some View {
        PaperSection("本周亮点", subtitle: highlightText, systemImage: "sun.max.fill") {
            HStack(spacing: GuozaiSpacing.small) {
                HighlightMetric(value: completedCount, label: "完成任务", symbol: "checkmark.circle.fill", color: GuozaiColor.ocean)
                HighlightMetric(value: achievedCount, label: "达成天数", symbol: "star.fill", color: GuozaiColor.mango)
                HighlightMetric(value: activeDomains, label: "成长领域", symbol: "leaf.fill", color: GuozaiColor.leaf)
            }
        }
    }

    private var highlightText: String {
        if completedCount == 0 { return "第一颗星正等着被点亮。" }
        if activeDomains >= 4 { return "这一周探索得很丰富，很多能力都在发芽。" }
        if achievedCount >= 5 { return "这一周的节奏很稳，给坚持的自己一个拥抱。" }
        return "已经留下 \(completedCount) 次认真完成的记录。"
    }
}

private struct HighlightMetric: View {
    let value: Int
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: GuozaiSpacing.xSmall) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(GuozaiColor.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GuozaiColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 108)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

private struct YearStarMap: View {
    @Binding var year: Int
    let today: LocalDay
    @Binding var selectedDay: LocalDay
    let tasksByDay: [String: [DailyTaskRecord]]

    private let calendar = Calendar.guozaiGregorian
    private let rows = Array(repeating: GridItem(.fixed(52), spacing: 5), count: 7)

    private var entries: [StarMapEntry] {
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let range = calendar.range(of: .day, in: .year, for: start)
        else { return [] }

        let sundayBasedWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = (sundayBasedWeekday + 5) % 7
        var result = (0..<mondayOffset).map { StarMapEntry(index: $0, day: nil) }
        for offset in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            result.append(StarMapEntry(index: result.count, day: LocalDay(date: date, calendar: calendar)))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            HStack(spacing: GuozaiSpacing.xSmall) {
                Button { moveYear(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 52, height: 52)
                }
                .accessibilityLabel("上一年")
                Text("\(year) 年")
                    .guozaiTextStyle(.control)
                    .foregroundStyle(GuozaiColor.ink)
                Button { moveYear(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 52, height: 52)
                }
                .disabled(year >= today.year)
                .accessibilityLabel("下一年")
                Spacer()
                Label("金色光环 = 当日达成", systemImage: "star.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GuozaiColor.inkMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 5) {
                    ForEach(entries) { entry in
                        if let day = entry.day {
                            let progress = StoredDailyProgress(tasks: tasksByDay[day.key, default: []])
                            Button {
                                selectedDay = day
                            } label: {
                                StarCell(
                                    progress: progress,
                                    isFuture: day > today,
                                    isSelected: day == selectedDay,
                                    isToday: day == today
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.key)，\(starDescription(progress, day: day))")
                        } else {
                            Color.clear.frame(width: 52, height: 52)
                        }
                    }
                }
                .padding(.vertical, GuozaiSpacing.small)
            }
            .frame(height: 420)
        }
    }

    private func starDescription(_ progress: StoredDailyProgress, day: LocalDay) -> String {
        if day > today { return "未来日期" }
        if progress.totalCount == 0 { return "暂无记录" }
        if progress.isAchieved { return "今日达成" }
        return "完成 \(progress.completedCount) 项，共 \(progress.totalCount) 项"
    }

    private func moveYear(_ offset: Int) {
        let nextYear = min(today.year, year + offset)
        guard nextYear > 0, nextYear != year else { return }
        year = nextYear
        selectedDay = LocalDay(year: nextYear, month: 1, day: 1)
    }
}

private struct StarMapEntry: Identifiable {
    let index: Int
    let day: LocalDay?
    var id: Int { index }
}

private struct StarCell: View {
    let progress: StoredDailyProgress
    let isFuture: Bool
    let isSelected: Bool
    let isToday: Bool

    private var starColor: Color {
        if isFuture || progress.totalCount == 0 { return GuozaiColor.line }
        return progress.isAchieved ? GuozaiColor.mango : GuozaiColor.ocean
    }

    private var starOpacity: Double {
        if isFuture || progress.totalCount == 0 { return 0.35 }
        return max(0.32, progress.requiredCompletionFraction)
    }

    var body: some View {
        ZStack {
            if progress.isAchieved {
                Circle()
                    .fill(GuozaiColor.mango.opacity(0.22))
                    .frame(width: 28, height: 28)
            }
            Image(systemName: "star.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(starColor.opacity(starOpacity))
            if isSelected || isToday {
                Circle()
                    .stroke(isSelected ? GuozaiColor.oceanDeep : GuozaiColor.mango, lineWidth: isSelected ? 2 : 1)
                    .frame(width: 27, height: 27)
            }
        }
        .frame(width: 52, height: 52)
        .contentShape(Circle())
    }
}

private struct MonthGrowthMap: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let monthContaining: LocalDay
    let today: LocalDay
    @Binding var selectedDay: LocalDay
    let tasksByDay: [String: [DailyTaskRecord]]

    private let calendar = Calendar.guozaiGregorian
    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var rowCount: Int {
        Int(ceil(Double(entries.count) / 7.0))
    }

    private var cellHeight: CGFloat { isCompact ? 62 : 70 }

    private var gridHeight: CGFloat {
        let spacing: CGFloat = isCompact ? 4 : 5
        return 28
            + GuozaiSpacing.small
            + CGFloat(rowCount) * cellHeight
            + CGFloat(max(rowCount - 1, 0)) * spacing
    }

    private var entries: [MonthMapEntry] {
        guard
            let start = calendar.date(from: DateComponents(year: monthContaining.year, month: monthContaining.month, day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: start)
        else { return [] }
        let mondayOffset = (calendar.component(.weekday, from: start) + 5) % 7
        var result = (0..<mondayOffset).map { MonthMapEntry(index: $0, day: nil) }
        for dayNumber in dayRange {
            result.append(MonthMapEntry(
                index: result.count,
                day: LocalDay(year: monthContaining.year, month: monthContaining.month, day: dayNumber)
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            monthNavigator
            monthGrid
        }
    }

    private var monthGrid: some View {
        GeometryReader { proxy in
            let metrics = MonthGridLayoutPolicy(isCompactWidth: isCompact)
                .metrics(availableWidth: proxy.size.width)
            let cellWidth = CGFloat(metrics.cellWidth)
            let spacing = CGFloat(metrics.spacing)
            let columns = Array(
                repeating: GridItem(.fixed(cellWidth), spacing: spacing),
                count: metrics.columnCount
            )

            VStack(spacing: GuozaiSpacing.small) {
                HStack(spacing: spacing) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GuozaiColor.inkMuted)
                            .frame(width: cellWidth, height: 28)
                    }
                }

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(entries) { entry in
                        if let day = entry.day {
                            let dayTasks = tasksByDay[day.key, default: []]
                            Button {
                                selectedDay = day
                            } label: {
                                MonthDayCell(
                                    day: day,
                                    tasks: dayTasks,
                                    isSelected: selectedDay == day,
                                    isFuture: day > today,
                                    width: cellWidth,
                                    height: cellHeight
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
            .frame(width: CGFloat(metrics.totalWidth), alignment: .leading)
        }
        .frame(height: gridHeight)
    }

    private var monthNavigator: some View {
        HStack {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 52, height: 52)
            }
            .accessibilityLabel("上个月")
            Spacer()
            Text("\(monthContaining.year) 年 \(monthContaining.month) 月")
                .guozaiTextStyle(.control)
                .foregroundStyle(GuozaiColor.ink)
            Spacer()
            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 52, height: 52)
            }
            .accessibilityLabel("下个月")
        }
    }

    private func moveMonth(_ value: Int) {
        guard
            let current = calendar.date(from: DateComponents(
                year: monthContaining.year,
                month: monthContaining.month,
                day: 1
            )),
            let next = calendar.date(byAdding: .month, value: value, to: current)
        else { return }
        selectedDay = LocalDay(date: next, calendar: calendar)
    }
}

private struct MonthMapEntry: Identifiable {
    let index: Int
    let day: LocalDay?
    var id: Int { index }
}

private struct MonthDayCell: View {
    let day: LocalDay
    let tasks: [DailyTaskRecord]
    let isSelected: Bool
    let isFuture: Bool
    let width: CGFloat
    let height: CGFloat

    private var completedDomains: Set<StoredGrowthDomain> {
        Set(tasks.filter { $0.status == .completed }.map(\.growthDomain))
    }

    var body: some View {
        VStack(spacing: 5) {
            Text("\(day.day)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(isFuture ? GuozaiColor.inkMuted.opacity(0.5) : GuozaiColor.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(7), spacing: 3), count: 3), spacing: 3) {
                ForEach(StoredGrowthDomain.allCases) { domain in
                    Circle()
                        .fill(completedDomains.contains(domain) ? domain.themeColor : GuozaiColor.line.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(width: width, height: height)
        .background(
            isSelected ? GuozaiColor.oceanSoft : GuozaiColor.canvasWarm.opacity(0.55),
            in: RoundedRectangle(cornerRadius: GuozaiRadius.small)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.small)
                .stroke(isSelected ? GuozaiColor.ocean : .clear, lineWidth: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.key)，成长领域 \(completedDomains.count) 个")
    }
}

private struct DayGrowthDetail: View {
    let day: LocalDay
    let today: LocalDay
    let tasks: [DailyTaskRecord]
    let reflection: DailyReflectionRecord?

    private var completed: [DailyTaskRecord] { tasks.filter { $0.status == .completed } }

    private var hasReflectionContent: Bool {
        guard let reflection else { return false }
        return reflection.mood != nil
            || reflection.rating != nil
            || !reflection.proudMoment.isEmpty
            || !reflection.parentEncouragement.isEmpty
    }

    var body: some View {
        PaperSection(dayTitle, subtitle: detailSubtitle, systemImage: "calendar") {
            if tasks.isEmpty && !hasReflectionContent {
                ContentUnavailableView(
                    day > today ? "这一天还没到" : "这一天还没有记录",
                    systemImage: day > today ? "sunrise" : "star",
                    description: Text(day > today ? "未来会在这里长出新的星星。" : "空白不是失败，只是还没有留下记录。")
                )
            } else {
                VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
                    ForEach(tasks) { task in
                        HStack(alignment: .top, spacing: GuozaiSpacing.medium) {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : task.status == .skipped ? "forward.end.circle" : "circle")
                                .font(.title3)
                                .foregroundStyle(task.status == .completed ? task.growthDomain.themeColor : GuozaiColor.inkMuted)
                            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                                Text(task.title)
                                    .guozaiTextStyle(.body)
                                    .foregroundStyle(GuozaiColor.ink)
                                Text(displayStatus(task))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(GuozaiColor.inkMuted)
                            }
                        }
                    }

                    if let reflection, hasReflectionContent {
                        if !tasks.isEmpty {
                            Divider()
                        }

                        if reflection.mood != nil || reflection.rating != nil {
                            DayReflectionSummary(
                                mood: reflection.mood,
                                rating: reflection.rating
                            )
                        }

                        if !reflection.proudMoment.isEmpty {
                            Label(reflection.proudMoment, systemImage: "heart.text.square.fill")
                                .guozaiTextStyle(.body)
                                .foregroundStyle(GuozaiColor.oceanDeep)
                        }

                        if !reflection.parentEncouragement.isEmpty {
                            Label(reflection.parentEncouragement, systemImage: "heart.fill")
                                .guozaiTextStyle(.body)
                                .foregroundStyle(GuozaiColor.coral)
                                .padding(GuozaiSpacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(GuozaiColor.coralSoft, in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
                        }
                    }
                }
            }
        }
    }

    private var dayTitle: String { "\(day.month) 月 \(day.day) 日" }

    private var detailSubtitle: String {
        let progress = StoredDailyProgress(tasks: tasks)
        if tasks.isEmpty && hasReflectionContent { return "这一天留下了心情和回顾。" }
        if progress.isAchieved { return "这一天的必做任务全部完成，星星闪闪发光。" }
        if completed.isEmpty { return day < today ? "这一天没有完成记录。" : "从一件小事开始吧。" }
        return "完成了 \(completed.count) 项，每一步都算数。"
    }

    private func displayStatus(_ task: DailyTaskRecord) -> String {
        switch task.status {
        case .completed:
            if let value = task.actualValue, let unit = task.targetUnit {
                return "完成 \(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
            }
            return "已完成"
        case .skipped:
            return task.skipReason?.isEmpty == false ? "已跳过 · \(task.skipReason!)" : "已跳过"
        case .pending:
            return day < today ? "未完成" : "待完成"
        }
    }
}

private struct DayReflectionSummary: View {
    let mood: StoredMood?
    let rating: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            Text("当天回顾")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GuozaiColor.ink)

            HStack(spacing: GuozaiSpacing.medium) {
                if let mood {
                    Label(mood.title, systemImage: mood.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GuozaiColor.oceanDeep)
                        .padding(.horizontal, GuozaiSpacing.medium)
                        .frame(minHeight: 40)
                        .background(GuozaiColor.oceanSoft, in: Capsule())
                }

                if let rating {
                    HStack(spacing: GuozaiSpacing.xSmall) {
                        ForEach(1...5, id: \.self) { value in
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .foregroundStyle(GuozaiColor.mango)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("当天自评 \(rating) 颗星")
                }
            }
        }
        .padding(GuozaiSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GuozaiColor.canvasWarm.opacity(0.55), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
    }
}
