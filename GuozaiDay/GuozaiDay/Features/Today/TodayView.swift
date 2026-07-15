import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @Query(sort: [SortDescriptor(\DailyTaskRecord.sortOrder), SortDescriptor(\DailyTaskRecord.createdAt)])
    private var allTasks: [DailyTaskRecord]

    @State private var reflection: DailyReflectionRecord?
    @State private var isShowingChallenge = false
    @State private var quantityTask: DailyTaskRecord?
    @State private var recentlyCompletedTask: DailyTaskRecord?
    @State private var undoToken = UUID()
    @State private var praiseMoment: CompletionPraiseMoment?
    @State private var praiseToken = UUID()
    @State private var errorMessage: String?
    @State private var hasBootstrapped = false
    @State private var isBootstrapping = false
    @State private var today = LocalDay(date: .now)
    @State private var now = Date.now
    private var activeProfileID: UUID? { profiles.first?.id }

    private var tasks: [DailyTaskRecord] {
        guard let activeProfileID else { return [] }
        return allTasks.filter { $0.profileId == activeProfileID && $0.dayKey == today.key }
    }

    private var requiredTasks: [DailyTaskRecord] {
        tasks.filter { $0.requirement == .required }
    }

    private var optionalTasks: [DailyTaskRecord] {
        tasks.filter { $0.requirement == .optional }
    }

    private var progress: StoredDailyProgress {
        StoredDailyProgress(tasks: tasks)
    }

    private var gardenProgress: GrowthGardenProgress {
        guard let activeProfileID else {
            return GrowthGardenProgress(achievedDayCount: 0)
        }
        return GrowthGardenProgress(
            tasks: allTasks
                .filter { $0.profileId == activeProfileID }
                .compactMap(\.coreSnapshot)
        )
    }

    private var layoutPolicy: TodayLayoutPolicy {
        TodayLayoutPolicy(isCompactWidth: isCompact)
    }

    private var planSubtitle: String {
        progress.isAchieved ? "必做任务已经完成，今天的星星点亮啦！" : "一件一件来，每完成一件都在成长。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompact ? GuozaiSpacing.medium : GuozaiSpacing.xLarge) {
                todayPlanModule

                if let reflection {
                    ReflectionCard(reflection: reflection) { errorMessage = $0 }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(.horizontal, isCompact ? GuozaiSpacing.medium : GuozaiSpacing.large)
            .padding(.vertical, isCompact ? GuozaiSpacing.small : GuozaiSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(GuozaiColor.canvasWarm.ignoresSafeArea())
        .overlay {
            if let praiseMoment {
                CompletionPraiseOverlay(moment: praiseMoment)
                    .id(praiseMoment.id)
                    .transition(praiseTransition)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .navigationTitle(isCompact ? "" : "今日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isCompact ? .hidden : .visible, for: .navigationBar)
        .task {
            CompletionSoundPlayer.shared.prepare()
            refreshCurrentDay()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshCurrentDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshCurrentDay()
        }
        .sheet(isPresented: $isShowingChallenge) {
            ChallengeEditor { title, domain in
                addChallenge(title: title, domain: domain)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $quantityTask) { task in
            QuantityEditor(task: task) { value in
                recordQuantity(value, for: task)
            }
            .presentationDetents([.height(330)])
        }
        .safeAreaInset(edge: .bottom) {
            if let recentlyCompletedTask {
                UndoBar(taskTitle: recentlyCompletedTask.title) {
                    undoCompletion(recentlyCompletedTask)
                }
                .padding(.horizontal, GuozaiSpacing.large)
                .padding(.bottom, GuozaiSpacing.small)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("操作暂时没有完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后再试。")
        }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var todayPlanModule: some View {
        VStack(spacing: 0) {
            todayHeader

            VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
                planHeader
                planTaskList
            }
            .padding(.horizontal, isCompact ? GuozaiSpacing.large : GuozaiSpacing.xLarge)
            .padding(.top, isCompact ? GuozaiSpacing.medium : GuozaiSpacing.large)
            .padding(.bottom, isCompact ? GuozaiSpacing.large : GuozaiSpacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GuozaiColor.paper)
        }
        .background(GuozaiColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous)
                .stroke(GuozaiColor.line.opacity(0.58), lineWidth: 0.75)
        }
        .shadow(color: GuozaiColor.leaf.opacity(0.10), radius: 14, y: 5)
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
            HStack(spacing: GuozaiSpacing.small) {
                Image(systemName: "checklist")
                    .foregroundStyle(GuozaiColor.ocean)
                    .accessibilityHidden(true)
                Text("今天的小计划")
                    .font(Font.custom("Kaiti SC", size: isCompact ? 20 : 26, relativeTo: .title2).weight(.bold))
                    .foregroundStyle(GuozaiColor.ink)
            }

            if layoutPolicy.showsPlanSubtitle {
                Text(planSubtitle)
                    .guozaiTextStyle(.body)
                    .foregroundStyle(GuozaiColor.inkMuted)
            }
        }
    }

    private var planTaskList: some View {
        VStack(spacing: 0) {
            TaskGroupHeader(title: "必做任务", count: requiredTasks.count, color: GuozaiColor.ocean)
            taskRows(requiredTasks)

            if !optionalTasks.isEmpty {
                Divider()
                    .padding(.vertical, GuozaiSpacing.medium)
                TaskGroupHeader(title: "选做与挑战", count: optionalTasks.count, color: GuozaiColor.mango)
                taskRows(optionalTasks)
            }

            Button {
                isShowingChallenge = true
            } label: {
                Label("添加“我的挑战”", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(GuozaiColor.oceanDeep)
            .guozaiTextStyle(.control)
            .background(GuozaiColor.oceanSoft, in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
            .padding(.top, GuozaiSpacing.large)
            .accessibilityHint("添加一项今天想主动完成的选做任务")
        }
    }

    private var todayHeader: some View {
        Group {
            if layoutPolicy.usesCondensedHeader {
                compactTodayHeader
            } else {
                HStack(alignment: .center, spacing: GuozaiSpacing.xLarge) {
                    VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
                        headerCopy
                        GuozaiJourneyProgress(progress: progress)
                    }
                    DateStamp(date: now)
                }
            }
        }
        .padding(.horizontal, isCompact ? GuozaiSpacing.large : GuozaiSpacing.xLarge)
        .padding(.vertical, GuozaiSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            TodayHeaderGardenBackground(isAchieved: progress.isAchieved)
        }
    }

    private var compactTodayHeader: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            headerCopy
            GuozaiJourneyProgress(progress: progress, date: now)
        }
    }

    private var headerCopy: some View {
        Text("果仔的一天")
            .font(
                Font.custom(
                    "Kaiti SC",
                    size: isCompact ? 26 : 40,
                    relativeTo: .largeTitle
                )
                .weight(.bold)
            )
            .foregroundStyle(GuozaiColor.ink)
    }

    @ViewBuilder
    private func taskRows(_ rows: [DailyTaskRecord]) -> some View {
        if rows.isEmpty {
            Text("这里还没有任务")
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 72)
        } else {
            ForEach(rows) { task in
                StrikeThroughTaskRow(
                    task: task,
                    onToggle: { toggle(task) },
                    onSkip: { skip(task) },
                    onReset: { reset(task) },
                    onQuantity: task.targetValue == nil ? nil : {
                        quantityTask = task
                    }
                )

                if task.id != rows.last?.id {
                    Divider()
                        .overlay(GuozaiColor.line)
                        .padding(.leading, 64)
                }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() {
        guard !hasBootstrapped, !isBootstrapping else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            let profile = try SeedService.ensureSeeded(in: modelContext, today: today)
            try DailyPlanStore.syncCurrentPlanFromTemplates(
                for: today,
                profile: profile,
                in: modelContext
            )
            reflection = try DailyPlanStore.ensureReflection(for: today, profile: profile, in: modelContext)
            try AchievementStore.evaluate(profileId: profile.id, in: modelContext)
            hasBootstrapped = true
            Task { @MainActor in
                do {
                    try await ReminderMaintenanceService.syncTemplateReminders(in: modelContext)
                } catch {
                    errorMessage = "今日计划已准备好，但提醒没有续排：\(error.localizedDescription)"
                }
            }
        } catch {
            hasBootstrapped = false
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshCurrentDay() {
        let currentDate = Date.now
        let currentDay = LocalDay(date: currentDate)
        now = currentDate

        if currentDay != today {
            today = currentDay
            reflection = nil
            recentlyCompletedTask = nil
            undoToken = UUID()
            praiseMoment = nil
            praiseToken = UUID()
            quantityTask = nil
            isShowingChallenge = false
            hasBootstrapped = false
        }
        bootstrapIfNeeded()
    }

    private func toggle(_ task: DailyTaskRecord) {
        do {
            let wasCompleted = task.status == .completed
            let wasAchieved = progress.isAchieved
            try CheckInService.toggleCompletion(task, in: modelContext)
            try AchievementStore.evaluate(profileId: task.profileId, in: modelContext)
            if !wasCompleted {
                showUndo(for: task)
                showPraise(for: task, isDayAchieved: !wasAchieved && StoredDailyProgress(tasks: tasks).isAchieved)
            } else if praiseMoment?.taskID == task.id {
                dismissPraise()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func skip(_ task: DailyTaskRecord) {
        do {
            try CheckInService.skip(task, reason: "", in: modelContext)
            if recentlyCompletedTask?.id == task.id { recentlyCompletedTask = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset(_ task: DailyTaskRecord) {
        do {
            try CheckInService.reset(task, in: modelContext)
            if recentlyCompletedTask?.id == task.id { recentlyCompletedTask = nil }
            if praiseMoment?.taskID == task.id { dismissPraise() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addChallenge(title: String, domain: StoredGrowthDomain) {
        guard let profile = profiles.first else { return }
        do {
            try DailyPlanStore.addOneOffTask(
                title: title,
                domain: domain,
                requirement: .optional,
                origin: .childChallenge,
                day: today,
                profile: profile,
                in: modelContext
            )
            try AchievementStore.evaluate(profileId: profile.id, in: modelContext)
            isShowingChallenge = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordQuantity(_ value: Double, for task: DailyTaskRecord) {
        do {
            var newlyCompleted = false
            var dayAchieved = false
            if task.status != .completed {
                let wasAchieved = progress.isAchieved
                try CheckInService.toggleCompletion(task, actualValue: value, in: modelContext)
                try AchievementStore.evaluate(profileId: task.profileId, in: modelContext)
                showUndo(for: task)
                newlyCompleted = true
                dayAchieved = !wasAchieved && StoredDailyProgress(tasks: tasks).isAchieved
            } else {
                task.actualValue = value
                task.updatedAt = .now
                try PersistenceWriter.save(modelContext)
            }
            quantityTask = nil
            if newlyCompleted {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(260))
                    guard task.status == .completed else { return }
                    showPraise(for: task, isDayAchieved: dayAchieved)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showUndo(for task: DailyTaskRecord) {
        let token = UUID()
        undoToken = token
        withAnimation(.easeOut(duration: 0.18)) {
            recentlyCompletedTask = task
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard undoToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                recentlyCompletedTask = nil
            }
        }
    }

    private func undoCompletion(_ task: DailyTaskRecord) {
        do {
            try CheckInService.toggleCompletion(task, in: modelContext)
            undoToken = UUID()
            if praiseMoment?.taskID == task.id {
                dismissPraise()
            }
            withAnimation(.easeOut(duration: 0.16)) {
                recentlyCompletedTask = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var praiseTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.78).combined(with: .opacity)
    }

    private func showPraise(for task: DailyTaskRecord, isDayAchieved: Bool) {
        let copy = task.coreSnapshot.map {
            CompletionPraiseCopy.make(for: $0, isDayAchieved: isDayAchieved)
        } ?? CompletionPraise(
            title: isDayAchieved ? "今天的计划完成了" : "这一步完成了",
            message: isDayAchieved
                ? "你一项一项完成了今天的计划，小树也长大了一步。"
                : "你认真完成了刚才的计划。"
        )
        let moment = CompletionPraiseMoment(
            taskID: task.id,
            taskTitle: task.title,
            title: copy.title,
            message: copy.message,
            isDayAchieved: isDayAchieved,
            gardenProgress: isDayAchieved ? gardenProgress : nil
        )
        let token = UUID()
        praiseToken = token

        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.38, dampingFraction: 0.7)) {
            praiseMoment = moment
        }

        CompletionSoundPlayer.shared.play(isDayAchieved ? .dayAchieved : .taskComplete)
        UIAccessibility.post(notification: .announcement, argument: "\(moment.title)，\(moment.message)")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(isDayAchieved ? 2.4 : 1.8))
            guard praiseToken == token else { return }
            dismissPraise()
        }
    }

    private func dismissPraise() {
        praiseToken = UUID()
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2)) {
            praiseMoment = nil
        }
    }

}

private struct TaskGroupHeader: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Label(title, systemImage: title == "必做任务" ? "star.fill" : "sparkles")
                .guozaiTextStyle(.control)
                .foregroundStyle(GuozaiColor.ink)
            Spacer()
            Text("\(count) 项")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(GuozaiColor.inkMuted)
        }
        .symbolRenderingMode(.hierarchical)
        .tint(color)
        .padding(.bottom, GuozaiSpacing.small)
    }
}

private struct StrikeThroughTaskRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let task: DailyTaskRecord
    let onToggle: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void
    let onQuantity: (() -> Void)?

    @State private var dragProgress = 0.0
    @State private var didCrossThreshold = false
    @State private var textWidth: CGFloat = 1
    @ScaledMetric(relativeTo: .body) private var compactTaskSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title3) private var regularTaskSize: CGFloat = 22

    private var domainColor: Color { task.growthDomain.themeColor }
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        HStack(alignment: .center, spacing: isCompact ? GuozaiSpacing.small : GuozaiSpacing.medium) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? domainColor : domainColor.opacity(0.12))
                    Circle()
                        .stroke(domainColor, lineWidth: 2.5)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    } else if task.status == .skipped {
                        Image(systemName: "minus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(domainColor)
                    }
                }
                .frame(width: isCompact ? 34 : 38, height: isCompact ? 34 : 38)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "取消完成：\(task.title)" : "完成：\(task.title)")
            .accessibilityValue(task.status.accessibilityTitle)

            strikeableTitle
                .layoutPriority(2)

            Label(inlineTagTitle, systemImage: task.growthDomain.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(domainColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: GuozaiSpacing.small)

            if task.status == .skipped {
                Text("跳过")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GuozaiColor.coral)
                    .lineLimit(1)
            }

            if let target = task.targetValue,
               let unit = task.targetUnit,
               let onQuantity {
                Button(action: onQuantity) {
                    Label(quantityText(target: target, unit: unit), systemImage: "ruler")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(GuozaiColor.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(GuozaiColor.paper.opacity(0.55), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(GuozaiColor.line.opacity(0.72), lineWidth: 0.75)
                        }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityHint("记录实际完成量")
            }
        }
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .simultaneousGesture(strikeGesture)
        .contextMenu {
            if task.status == .pending {
                Button("今天跳过", systemImage: "forward.end") { onSkip() }
            } else {
                Button("恢复为待完成", systemImage: "arrow.uturn.backward") { onReset() }
            }
        }
        .accessibilityHint(rowAccessibilityHint)
        .accessibilityAction(named: Text(task.status == .pending ? "今天跳过" : "恢复为待完成")) {
            task.status == .pending ? onSkip() : onReset()
        }
    }

    private var inlineTagTitle: String {
        task.tags.first ?? task.growthDomain.title
    }

    private var rowAccessibilityHint: String {
        switch task.status {
        case .pending:
            "整行向右滑动可以完成，长按可以选择今天跳过"
        case .completed:
            "可用左侧按钮取消完成，长按可以恢复为待完成"
        case .skipped:
            "长按可以恢复为待完成"
        }
    }

    private var strikeableTitle: some View {
        Text(task.title)
            .font(
                .system(
                    size: isCompact ? compactTaskSize : regularTaskSize,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(task.isCompleted ? GuozaiColor.inkMuted : GuozaiColor.ink)
            .lineLimit(isCompact ? 2 : 1)
            .minimumScaleFactor(isCompact ? 0.86 : 1)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: TaskTextWidthPreferenceKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(TaskTextWidthPreferenceKey.self) { textWidth = max($0, 1) }
            .overlay {
                GeometryReader { proxy in
                    let visibleProgress = task.isCompleted ? 1.0 : dragProgress
                    HandDrawnStrikeLine()
                        .trim(from: 0, to: visibleProgress)
                        .stroke(domainColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(visibleProgress > 0 ? 0.88 : 0)
                }
            }
            .contentShape(Rectangle())
    }

    private var strikeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard task.status == .pending else { return }
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 0, horizontal > vertical * 1.25 else { return }
                let progress = min(1, horizontal / textWidth)
                dragProgress = progress
                if progress >= 0.6, !didCrossThreshold {
                    didCrossThreshold = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { _ in
                guard task.status == .pending else {
                    resetGestureState()
                    return
                }
                let shouldComplete = dragProgress >= 0.6
                if shouldComplete {
                    onToggle()
                }
                if reduceMotion {
                    resetGestureState()
                } else {
                    withAnimation(.easeOut(duration: 0.16)) {
                        dragProgress = 0
                    }
                    didCrossThreshold = false
                }
            }
    }

    private func resetGestureState() {
        dragProgress = 0
        didCrossThreshold = false
    }

    private func quantityText(target: Double, unit: String) -> String {
        let value = task.actualValue ?? target
        let prefix = task.actualValue == nil ? "目标" : "完成"
        return "\(prefix) \(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }
}

private struct TaskTextWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HandDrawnStrikeLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY + 1
        path.move(to: CGPoint(x: 1, y: y + 1))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.52, y: y - 1.5),
            control1: CGPoint(x: rect.width * 0.16, y: y - 2),
            control2: CGPoint(x: rect.width * 0.36, y: y + 2)
        )
        path.addCurve(
            to: CGPoint(x: rect.width - 1, y: y),
            control1: CGPoint(x: rect.width * 0.68, y: y - 3),
            control2: CGPoint(x: rect.width * 0.84, y: y + 2)
        )
        return path
    }
}

private struct TodayHeaderGardenBackground: View {
    let isAchieved: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GuozaiColor.paper

                Image("TodayHeaderMorningBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .saturation(0.68)
                    .contrast(0.90)
                    .opacity(0.46)

                LinearGradient(
                    colors: [
                        GuozaiColor.paper.opacity(0.18),
                        GuozaiColor.paper.opacity(0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [.clear, GuozaiColor.paper.opacity(0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 42)
                .frame(maxHeight: .infinity, alignment: .bottom)

                if isAchieved {
                    Image(systemName: "sparkles")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(GuozaiColor.mango.opacity(0.82))
                        .position(x: proxy.size.width * 0.43, y: 28)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GuozaiJourneyProgress: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let progress: StoredDailyProgress
    var date: Date?

    @State private var isHopping = false
    @State private var hopToken = UUID()

    init(progress: StoredDailyProgress, date: Date? = nil) {
        self.progress = progress
        self.date = date
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var hasFinished: Bool {
        progress.totalCount > 0 && progress.completedCount == progress.totalCount
    }

    var body: some View {
        VStack(spacing: GuozaiSpacing.xSmall) {
            HStack(spacing: GuozaiSpacing.small) {
                Label(
                    "\(progress.completedCount)/\(progress.totalCount) 已完成",
                    systemImage: hasFinished ? "flag.fill" : "figure.walk"
                )
                .foregroundStyle(hasFinished ? GuozaiColor.leaf : GuozaiColor.oceanDeep)

                Spacer(minLength: GuozaiSpacing.small)

                Text(date.map(Self.compactDateText) ?? journeyStatus)
                    .foregroundStyle(GuozaiColor.inkMuted)
                    .lineLimit(1)
            }
            .font(.caption.weight(.bold).monospacedDigit())

            journeyTrack
        }
        .onChange(of: progress.completedCount) { _, _ in
            playHop()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityProgressText)
    }

    private var journeyTrack: some View {
        GeometryReader { proxy in
            let mascotSize: CGFloat = isCompact ? 42 : 48
            let startX = mascotSize / 2
            let endX = max(startX, proxy.size.width - (isCompact ? 45 : 50))
            let trackLength = max(1, endX - startX)
            let fraction = min(max(progress.completionFraction, 0), 1)
            let mascotX = startX + trackLength * fraction
            let trackY = proxy.size.height * 0.58
            let markerCount = min(max(progress.totalCount, 1), 10)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(GuozaiColor.line.opacity(0.40))
                    .frame(width: trackLength, height: 4)
                    .offset(x: startX, y: trackY)

                Capsule()
                    .fill(hasFinished ? GuozaiColor.leaf.opacity(0.72) : GuozaiColor.mango.opacity(0.78))
                    .frame(width: trackLength, height: 4)
                    .scaleEffect(x: max(fraction, 0.001), anchor: .leading)
                    .offset(x: startX, y: trackY)

                if progress.totalCount > 0 {
                    ForEach(1...markerCount, id: \.self) { marker in
                        let markerFraction = Double(marker) / Double(markerCount)
                        Circle()
                            .fill(markerFraction <= fraction ? GuozaiColor.mango : GuozaiColor.paper)
                            .overlay {
                                Circle()
                                    .stroke(GuozaiColor.line.opacity(0.68), lineWidth: 1)
                            }
                            .frame(width: 8, height: 8)
                            .position(
                                x: startX + trackLength * markerFraction,
                                y: trackY + 2
                            )
                    }
                }

                Image(systemName: hasFinished ? "flag.fill" : "flag")
                    .font(.system(size: isCompact ? 20 : 23, weight: .bold))
                    .foregroundStyle(hasFinished ? GuozaiColor.leaf : GuozaiColor.inkMuted.opacity(0.52))
                    .scaleEffect(hasFinished && isHopping ? 1.16 : 1)
                    .rotationEffect(.degrees(hasFinished && isHopping ? -7 : 0))
                    .position(x: proxy.size.width - 13, y: trackY - 8)

                if hasFinished {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GuozaiColor.mango)
                        .opacity(isHopping ? 1 : 0.78)
                        .scaleEffect(isHopping ? 1.16 : 0.92)
                        .position(x: proxy.size.width - 34, y: 8)
                }

                Image("GuozaiMascot")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.32)
                    .frame(width: mascotSize, height: mascotSize)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(GuozaiColor.paper, lineWidth: 2.5)
                    }
                    .shadow(color: GuozaiColor.mango.opacity(0.22), radius: 4, y: 2)
                    .rotationEffect(.degrees(reduceMotion ? 0 : isHopping ? -6 : 0))
                    .offset(y: reduceMotion ? 0 : isHopping ? -7 : 0)
                    .position(x: mascotX, y: trackY)
            }
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .smooth(duration: 0.56),
                value: progress.completedCount
            )
        }
        .frame(height: isCompact ? 42 : 48)
        .accessibilityHidden(true)
    }

    private var journeyStatus: String {
        guard progress.totalCount > 0 else { return "计划准备中" }
        if hasFinished { return "抵达终点啦" }
        return "还差 \(progress.totalCount - progress.completedCount) 项"
    }

    private var accessibilityProgressText: String {
        if hasFinished {
            return "今日任务全部完成，果仔抵达终点"
        }
        return "今日完成 \(progress.completedCount) 项，共 \(progress.totalCount) 项，\(journeyStatus)"
    }

    private func playHop() {
        guard !reduceMotion else { return }
        let token = UUID()
        hopToken = token
        withAnimation(.easeOut(duration: 0.16)) {
            isHopping = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(190))
            guard hopToken == token else { return }
            withAnimation(.easeIn(duration: 0.17)) {
                isHopping = false
            }
        }
    }

    private static func compactDateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month()
                .day()
                .weekday(.short)
                .locale(Locale(identifier: "zh_Hans_CN"))
        )
    }
}

private struct CompactTodaySummary: View {
    let progress: StoredDailyProgress
    let date: Date

    private let locale = Locale(identifier: "zh_Hans_CN")

    var body: some View {
        HStack(spacing: GuozaiSpacing.medium) {
            Label(
                "\(progress.completedCount)/\(progress.totalCount) 完成",
                systemImage: progress.isAchieved ? "checkmark.circle.fill" : "circle.dashed"
            )
            .foregroundStyle(progress.isAchieved ? GuozaiColor.leaf : GuozaiColor.oceanDeep)

            Spacer(minLength: GuozaiSpacing.small)

            Label(dateText, systemImage: "calendar")
                .foregroundStyle(GuozaiColor.inkMuted)
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .padding(.horizontal, GuozaiSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(GuozaiColor.paper.opacity(0.78), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.control)
                .stroke(GuozaiColor.line.opacity(0.55), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日完成 \(progress.completedCount) 项，共 \(progress.totalCount) 项，\(dateText)")
    }

    private var dateText: String {
        date.formatted(
            .dateTime
                .month()
                .day()
                .weekday(.short)
                .locale(locale)
        )
    }
}

private struct ProgressMedallion: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let progress: StoredDailyProgress

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack {
            Circle()
                .stroke(GuozaiColor.line.opacity(0.65), lineWidth: isCompact ? 7 : 9)
            Circle()
                .trim(from: 0, to: progress.completionFraction)
                .stroke(
                    progress.isAchieved ? GuozaiColor.mango : GuozaiColor.ocean,
                    style: StrokeStyle(lineWidth: isCompact ? 7 : 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(progress.completedCount)/\(progress.totalCount)")
                    .font((isCompact ? Font.headline : Font.title3).bold().monospacedDigit())
                    .foregroundStyle(GuozaiColor.ink)
                Text(progress.isAchieved ? "达成" : "完成")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GuozaiColor.inkMuted)
            }
        }
        .frame(width: isCompact ? 72 : 92, height: isCompact ? 72 : 92)
        .shadow(color: progress.isAchieved ? GuozaiColor.mango.opacity(0.35) : .clear, radius: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日进度")
        .accessibilityValue("完成 \(progress.completedCount) 项，共 \(progress.totalCount) 项")
    }
}

private struct ReflectionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var reflection: DailyReflectionRecord
    let onError: (String) -> Void

    var body: some View {
        PaperSection(
            "今天的回顾",
            subtitle: "留下一点心情，也夸夸今天的自己。",
            systemImage: "sun.horizon.fill",
            compactDensity: true
        ) {
            VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
                Text("今天感觉怎么样？")
                    .guozaiTextStyle(.control)
                    .foregroundStyle(GuozaiColor.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GuozaiSpacing.small) {
                        ForEach(StoredMood.allCases) { mood in
                            Button {
                                reflection.mood = mood
                                persist()
                            } label: {
                                Label(mood.title, systemImage: mood.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 52)
                                    .foregroundStyle(reflection.mood == mood ? GuozaiColor.oceanDeep : GuozaiColor.inkMuted)
                                    .background(
                                        reflection.mood == mood ? GuozaiColor.mangoSoft : GuozaiColor.canvasWarm,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(reflection.mood == mood ? "已选择" : "未选择")
                            .accessibilityAddTraits(reflection.mood == mood ? .isSelected : [])
                        }
                    }
                }

                Text("给今天几颗星？")
                    .guozaiTextStyle(.control)
                    .foregroundStyle(GuozaiColor.ink)

                HStack(spacing: GuozaiSpacing.small) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            reflection.rating = rating
                            persist()
                        } label: {
                            Image(systemName: rating <= (reflection.rating ?? 0) ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(GuozaiColor.mango)
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(rating) 颗星")
                        .accessibilityValue(reflection.rating == rating ? "已选择" : "未选择")
                        .accessibilityAddTraits(reflection.rating == rating ? .isSelected : [])
                    }
                }

                TextField("今天最让我骄傲的是……", text: $reflection.proudMoment, axis: .vertical)
                    .lineLimit(2...5)
                    .guozaiTextStyle(.body)
                    .padding(GuozaiSpacing.medium)
                    .background(GuozaiColor.canvasWarm, in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
                    .onSubmit { persist() }

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

    private func persist() {
        reflection.updatedAt = .now
        do {
            try PersistenceWriter.save(modelContext)
        } catch {
            onError(error.localizedDescription)
        }
    }
}

private struct ChallengeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var domain: StoredGrowthDomain = .exploration

    let onSave: (String, StoredGrowthDomain) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("我的挑战") {
                    TextField("我今天还想……", text: $title, axis: .vertical)
                        .font(.title3)
                        .lineLimit(2...4)
                    Picker("成长领域", selection: $domain) {
                        ForEach(StoredGrowthDomain.allCases) { domain in
                            Label(domain.title, systemImage: domain.symbol).tag(domain)
                        }
                    }
                }
                Section {
                    Text("挑战是选做任务，不会影响“今日达成”。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加挑战")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), domain)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct QuantityEditor: View {
    @Environment(\.dismiss) private var dismiss
    let task: DailyTaskRecord
    let onSave: (Double) -> Void
    @State private var valueText: String

    init(task: DailyTaskRecord, onSave: @escaping (Double) -> Void) {
        self.task = task
        self.onSave = onSave
        let initial = task.actualValue ?? task.targetValue ?? 0
        _valueText = State(initialValue: initial.formatted(.number.precision(.fractionLength(0...1))))
    }

    private var parsedValue: Double? {
        guard
            let value = Double(valueText.replacingOccurrences(of: ",", with: ".")),
            value.isFinite,
            value >= 0
        else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
                Text(task.title)
                    .guozaiTextStyle(.sectionTitle)
                    .foregroundStyle(GuozaiColor.ink)
                HStack(alignment: .firstTextBaseline) {
                    TextField("完成量", text: $valueText)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(GuozaiColor.canvasWarm, in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
                    Text(task.targetUnit ?? "")
                        .guozaiTextStyle(.body)
                        .foregroundStyle(GuozaiColor.inkMuted)
                }
                if parsedValue == nil {
                    Label("请输入 0 或更大的数字", systemImage: "exclamationmark.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GuozaiColor.coral)
                }
                Spacer()
            }
            .padding(GuozaiSpacing.large)
            .background(GuozaiColor.paper)
            .navigationTitle("记录完成量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let value = parsedValue {
                            onSave(value)
                        }
                    }
                    .disabled(parsedValue == nil)
                }
            }
        }
    }
}

private struct UndoBar: View {
    let taskTitle: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: GuozaiSpacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(GuozaiColor.leaf)
            Text("完成：\(taskTitle)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Button("撤销", action: onUndo)
                .font(.headline)
                .frame(minWidth: 64, minHeight: 52)
        }
        .foregroundStyle(GuozaiColor.ink)
        .padding(.leading, GuozaiSpacing.medium)
        .padding(.trailing, GuozaiSpacing.small)
        .frame(minHeight: 60)
        .background(GuozaiColor.paper, in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
        .shadow(color: GuozaiColor.ink.opacity(0.14), radius: 12, y: 4)
    }
}
