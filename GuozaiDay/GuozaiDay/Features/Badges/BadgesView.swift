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

                WishRewardsSection(rewards: profileRewards)
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

    var body: some View {
        PaperSection(
            "心愿奖励",
            subtitle: rewards.isEmpty ? "家长可以把一次特别体验设为成长后的惊喜。" : "努力会打开惊喜，但不需要用积分交换。",
            systemImage: "gift.fill"
        ) {
            if rewards.isEmpty {
                Label("还没有设置心愿，和家长一起想一个吧。", systemImage: "wand.and.stars")
                    .guozaiTextStyle(.body)
                    .foregroundStyle(GuozaiColor.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            } else {
                VStack(spacing: GuozaiSpacing.medium) {
                    ForEach(rewards) { reward in
                        HStack(spacing: GuozaiSpacing.medium) {
                            ZStack {
                                Circle().fill(reward.state == .locked ? GuozaiColor.canvasWarm : GuozaiColor.mangoSoft)
                                Image(systemName: reward.state == .claimed ? "gift.fill" : reward.state == .unlocked ? "party.popper.fill" : "sparkles")
                                    .foregroundStyle(reward.state == .locked ? GuozaiColor.inkMuted : GuozaiColor.mango)
                            }
                            .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                                Text(reward.title)
                                    .guozaiTextStyle(.control)
                                    .foregroundStyle(GuozaiColor.ink)
                                if !reward.detail.isEmpty {
                                    Text(reward.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(GuozaiColor.inkMuted)
                                }
                            }
                            Spacer()
                            Text(stateTitle(reward.state))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(reward.state == .locked ? GuozaiColor.inkMuted : GuozaiColor.oceanDeep)
                        }
                        .frame(minHeight: 64)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func stateTitle(_ state: StoredWishState) -> String {
        switch state {
        case .locked: "成长中"
        case .unlocked: "已解锁"
        case .claimed: "已领取"
        }
    }
}
