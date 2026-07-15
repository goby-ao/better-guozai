import SwiftData
import SwiftUI

struct BadgesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @Query(sort: \BadgeAwardRecord.awardedAt, order: .reverse) private var awards: [BadgeAwardRecord]
    @Query(sort: \WishRewardRecord.createdAt) private var rewards: [WishRewardRecord]
    @Query(sort: \DailyTaskRecord.updatedAt) private var tasks: [DailyTaskRecord]

    @State private var newestAwards: [BadgeAwardRecord] = []
    @State private var errorMessage: String?

    private var profileID: UUID? { profiles.first?.id }

    private var profileAwards: [BadgeAwardRecord] {
        guard let profileID else { return [] }
        return awards.filter { $0.profileId == profileID }
    }

    private var profileRewards: [WishRewardRecord] {
        guard let profileID else { return [] }
        return rewards.filter { $0.profileId == profileID }
    }

    private var profileTasks: [DailyTaskRecord] {
        guard let profileID else { return [] }
        return tasks.filter { $0.profileId == profileID }
    }

    private var systemAwards: [String: BadgeAwardRecord] {
        Dictionary(grouping: profileAwards.filter { $0.source == .system }, by: \.stableBadgeId)
            .compactMapValues { $0.first }
    }

    private var specialAwards: [BadgeAwardRecord] {
        profileAwards.filter { $0.source == .parent }
    }

    private var evaluationKey: String {
        profileTasks.map { "\($0.id.uuidString):\($0.statusRaw):\($0.updatedAt.timeIntervalSinceReferenceDate)" }
            .joined(separator: "|")
    }

    private var achievedThisWeek: Int {
        AchievementStore.currentWeekAchievedDayCount(
            tasks: profileTasks,
            today: LocalDay(date: .now)
        )
    }

    private var weeklyWishUnlockedThisWeek: Bool {
        WishRewardStore.hasUnlockedWeeklyWish(
            in: profileRewards,
            weekContaining: LocalDay(date: .now)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuozaiSpacing.xLarge) {
                header

                if !newestAwards.isEmpty {
                    NewBadgeBanner(awards: newestAwards)
                }

                PaperSection(
                    "系统勋章",
                    subtitle: "每枚勋章都有清楚的成长故事，得到后会永久保留。",
                    systemImage: "medal.fill"
                ) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: GuozaiSpacing.medium)],
                        spacing: GuozaiSpacing.medium
                    ) {
                        ForEach(BadgeCode.allCases.map(BadgePresentation.init(code:))) { presentation in
                            BadgeTile(
                                presentation: presentation,
                                award: systemAwards[presentation.code.rawValue]
                            )
                        }
                    }
                }

                if !specialAwards.isEmpty {
                    PaperSection(
                        "家长特别勋章",
                        subtitle: "这些勋章记录了家长眼中独一无二的成长时刻。",
                        systemImage: "heart.circle.fill"
                    ) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 210), spacing: GuozaiSpacing.medium)],
                            spacing: GuozaiSpacing.medium
                        ) {
                            ForEach(specialAwards) { award in
                                SpecialBadgeTile(award: award)
                            }
                        }
                    }
                }

                WishRewardsSection(
                    rewards: profileRewards,
                    achievedThisWeek: achievedThisWeek,
                    weeklyWishUnlockedThisWeek: weeklyWishUnlockedThisWeek,
                    onSelect: selectWish
                )
            }
            .frame(maxWidth: GuozaiLayout.readableContentWidth, alignment: .leading)
            .padding(.horizontal, GuozaiSpacing.large)
            .padding(.vertical, GuozaiSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(GuozaiColor.canvasWarm.ignoresSafeArea())
        .navigationTitle("勋章")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: evaluationKey) { evaluateAchievements() }
        .alert("勋章暂时没更新", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后再试。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            Text("成长勋章馆")
                .guozaiTextStyle(.pageTitle)
                .foregroundStyle(GuozaiColor.ink)
            Text("这里不比名次，只收藏每一次值得记住的进步。")
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.inkMuted)
        }
    }

    @MainActor
    private func evaluateAchievements() {
        do {
            let profile = try SeedService.ensureSeeded(in: modelContext)
            newestAwards = try AchievementStore.evaluate(profileId: profile.id, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func selectWish(_ reward: WishRewardRecord) {
        do {
            guard let profileID else { return }
            try WishRewardStore.select(reward, in: modelContext)
            _ = try AchievementStore.evaluate(profileId: profileID, in: modelContext)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct NewBadgeBanner: View {
    let awards: [BadgeAwardRecord]

    var body: some View {
        HStack(spacing: GuozaiSpacing.large) {
            ZStack {
                Circle().fill(GuozaiColor.mangoSoft)
                Image(systemName: "sparkles")
                    .font(.largeTitle.bold())
                    .foregroundStyle(GuozaiColor.mango)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                Text("新勋章点亮啦！")
                    .guozaiTextStyle(.sectionTitle)
                    .foregroundStyle(GuozaiColor.ink)
                Text(awards.map(\.title).joined(separator: "、"))
                    .guozaiTextStyle(.body)
                    .foregroundStyle(GuozaiColor.oceanDeep)
            }
            Spacer()
        }
        .padding(GuozaiSpacing.xLarge)
        .background(GuozaiColor.mangoSoft, in: RoundedRectangle(cornerRadius: GuozaiRadius.section))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section)
                .stroke(GuozaiColor.mango, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BadgeTile: View {
    let presentation: BadgePresentation
    let award: BadgeAwardRecord?

    private var isEarned: Bool { award != nil }
    private var color: Color {
        switch presentation.colorIndex {
        case 0: GuozaiColor.ocean
        case 1: GuozaiColor.mango
        case 2: GuozaiColor.leaf
        default: GuozaiColor.coral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            HStack(alignment: .top) {
                BadgeMedallion(symbol: presentation.symbol, color: color, isEarned: isEarned)
                Spacer()
                Text(isEarned ? "已获得" : "成长中")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isEarned ? GuozaiColor.oceanDeep : GuozaiColor.inkMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isEarned ? color.opacity(0.16) : GuozaiColor.canvasWarm, in: Capsule())
            }

            Text(presentation.title)
                .guozaiTextStyle(.control)
                .foregroundStyle(GuozaiColor.ink)

            Text(presentation.condition)
                .font(.subheadline)
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let award {
                Text(award.awardedAt.formatted(.dateTime.year().month().day()))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(GuozaiColor.oceanDeep)
            }
        }
        .padding(GuozaiSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(isEarned ? color.opacity(0.08) : GuozaiColor.canvasWarm.opacity(0.7), in: RoundedRectangle(cornerRadius: GuozaiRadius.section))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section)
                .stroke(isEarned ? color.opacity(0.55) : GuozaiColor.line, style: StrokeStyle(lineWidth: 1.25, dash: isEarned ? [] : [6]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title)，\(isEarned ? "已获得" : "未获得")，条件：\(presentation.condition)")
    }
}

private struct BadgeMedallion: View {
    let symbol: String
    let color: Color
    let isEarned: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isEarned ? color.opacity(0.18) : Color.clear)
            Circle()
                .stroke(color.opacity(isEarned ? 0.95 : 0.42), lineWidth: 3)
            Circle()
                .inset(by: 7)
                .stroke(color.opacity(isEarned ? 0.40 : 0.22), lineWidth: 2)
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(color.opacity(isEarned ? 1 : 0.48))
        }
        .frame(width: 72, height: 72)
        .shadow(color: isEarned ? color.opacity(0.20) : .clear, radius: 8)
    }
}

private struct SpecialBadgeTile: View {
    let award: BadgeAwardRecord

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            BadgeMedallion(symbol: award.symbol, color: GuozaiColor.coral, isEarned: true)
            Text(award.title)
                .guozaiTextStyle(.control)
                .foregroundStyle(GuozaiColor.ink)
            Text(award.detail)
                .font(.subheadline)
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(award.awardedAt.formatted(.dateTime.year().month().day()))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(GuozaiColor.coral)
        }
        .padding(GuozaiSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(GuozaiColor.coralSoft, in: RoundedRectangle(cornerRadius: GuozaiRadius.section))
        .accessibilityElement(children: .combine)
    }
}

private struct WishRewardsSection: View {
    let rewards: [WishRewardRecord]
    let achievedThisWeek: Int
    let weeklyWishUnlockedThisWeek: Bool
    let onSelect: (WishRewardRecord) -> Void

    private var sortedRewards: [WishRewardRecord] {
        rewards.sorted { lhs, rhs in
            let leftRank = sortRank(lhs)
            let rightRank = sortRank(rhs)
            return leftRank == rightRank ? lhs.createdAt < rhs.createdAt : leftRank < rightRank
        }
    }

    var body: some View {
        PaperSection(
            "心愿奖励",
            subtitle: rewards.isEmpty
                ? "家长可以把一次特别体验设为成长后的惊喜。"
                : "选一个最期待的心愿，本周达成 5 天就能解锁。",
            systemImage: "gift.fill"
        ) {
            if rewards.isEmpty {
                Label("还没有设置心愿，和家长一起想一个吧。", systemImage: "wand.and.stars")
                    .guozaiTextStyle(.body)
                    .foregroundStyle(GuozaiColor.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedRewards) { reward in
                        WishRewardRow(
                            reward: reward,
                            achievedThisWeek: achievedThisWeek,
                            weeklyWishUnlockedThisWeek: weeklyWishUnlockedThisWeek,
                            onSelect: { onSelect(reward) }
                        )

                        if reward.id != sortedRewards.last?.id {
                            Divider()
                                .overlay(GuozaiColor.line.opacity(0.7))
                                .padding(.vertical, GuozaiSpacing.small)
                        }
                    }
                }
            }
        }
    }

    private func sortRank(_ reward: WishRewardRecord) -> Int {
        if reward.state == .locked, reward.weeklyTarget != nil, reward.selectedAt != nil { return 0 }
        return switch reward.state {
        case .locked: 1
        case .unlocked: 2
        case .claimed: 3
        }
    }
}

private struct WishRewardRow: View {
    let reward: WishRewardRecord
    let achievedThisWeek: Int
    let weeklyWishUnlockedThisWeek: Bool
    let onSelect: () -> Void

    private var isWeeklyWish: Bool { reward.weeklyTarget != nil }
    private var isCurrentWish: Bool {
        reward.state == .locked && isWeeklyWish && reward.selectedAt != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            HStack(alignment: .top, spacing: GuozaiSpacing.medium) {
                ZStack {
                    Circle().fill(iconBackground)
                    Image(systemName: stateSymbol)
                        .font(.title3.bold())
                        .foregroundStyle(stateTint)
                }
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                    Text(reward.title)
                        .guozaiTextStyle(.control)
                        .foregroundStyle(GuozaiColor.ink)
                    if !reward.detail.isEmpty {
                        Text(reward.detail)
                            .font(.subheadline)
                            .foregroundStyle(GuozaiColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !isCurrentWish {
                        Label(conditionTitle, systemImage: conditionSymbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GuozaiColor.inkMuted)
                    }
                }

                Spacer(minLength: GuozaiSpacing.small)

                Text(stateTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stateTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stateTint.opacity(0.12), in: Capsule())
            }

            if isCurrentWish {
                WeeklyWishProgress(achievedCount: achievedThisWeek)
            } else if reward.state == .locked, isWeeklyWish {
                if weeklyWishUnlockedThisWeek {
                    Label("本周已经解锁一个心愿，下周再来选择。", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GuozaiColor.leaf)
                        .frame(maxWidth: .infinity, minHeight: GuozaiLayout.minimumTouchTarget, alignment: .leading)
                } else {
                    Button(action: onSelect) {
                        Label("选为本周心愿", systemImage: "heart.fill")
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: GuozaiLayout.minimumTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GuozaiColor.leaf)
                    .accessibilityHint("选中后，本周达成 5 天即可解锁")
                }
            }
        }
        .padding(isCurrentWish ? GuozaiSpacing.medium : 0)
        .background(
            isCurrentWish ? GuozaiColor.leafSoft.opacity(0.55) : Color.clear,
            in: RoundedRectangle(cornerRadius: GuozaiRadius.control, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private var conditionTitle: String {
        if let badgeID = reward.linkedBadgeId, let code = BadgeCode(rawValue: badgeID) {
            return "获得“\(BadgePresentation(code: code).title)”后解锁"
        }
        if isWeeklyWish {
            return "选中后，本周达成 5 天解锁"
        }
        return "等待成长条件"
    }

    private var conditionSymbol: String {
        reward.linkedBadgeId == nil ? "calendar.badge.checkmark" : "medal.fill"
    }

    private var stateTitle: String {
        if isCurrentWish { return "本周心愿" }
        return switch reward.state {
        case .locked: "待选择"
        case .unlocked: "已解锁"
        case .claimed: "已领取"
        }
    }

    private var stateSymbol: String {
        if isCurrentWish { return "heart.fill" }
        return switch reward.state {
        case .locked: "sparkles"
        case .unlocked: "party.popper.fill"
        case .claimed: "gift.fill"
        }
    }

    private var stateTint: Color {
        if isCurrentWish { return GuozaiColor.leaf }
        return switch reward.state {
        case .locked: GuozaiColor.inkMuted
        case .unlocked: GuozaiColor.mango
        case .claimed: GuozaiColor.oceanDeep
        }
    }

    private var iconBackground: Color {
        if isCurrentWish { return GuozaiColor.paper }
        return reward.state == .locked ? GuozaiColor.canvasWarm : GuozaiColor.mangoSoft
    }
}

private struct WeeklyWishProgress: View {
    let achievedCount: Int

    private var displayedCount: Int { min(max(achievedCount, 0), 7) }
    private var remainingCount: Int { max(0, 5 - achievedCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            HStack(spacing: GuozaiSpacing.small) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < displayedCount ? GuozaiColor.leaf : GuozaiColor.paper)
                        .overlay {
                            Circle()
                                .stroke(
                                    index == 4 ? GuozaiColor.mango : GuozaiColor.line,
                                    lineWidth: index == 4 ? 2 : 1
                                )
                        }
                        .frame(width: 22, height: 22)
                        .overlay {
                            if index < displayedCount {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }

            Text(remainingCount == 0 ? "已经达到 5 天目标，心愿正在解锁。" : "本周已达成 \(achievedCount) 天，再达成 \(remainingCount) 天就能解锁。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GuozaiColor.oceanDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本周已达成 \(achievedCount) 天，目标 5 天")
    }
}
