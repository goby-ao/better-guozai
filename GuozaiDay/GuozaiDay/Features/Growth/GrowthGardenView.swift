import SwiftUI

/// 把达成天数转译成不会被消费的成长花园。
struct GrowthGardenView: View {
    let progress: GrowthGardenProgress

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
            gardenHeader

            GrowthJourneyArtwork(progress: progress)

            growthTrail
            milestoneFooter
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GardenPaperBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous)
                .stroke(
                    GuozaiColor.leaf.opacity(colorSchemeContrast == .increased ? 0.72 : 0.22),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(color: GuozaiColor.leaf.opacity(0.10), radius: 18, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var cardPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact {
            return GuozaiSpacing.large
        }
        return GuozaiSpacing.xLarge
    }

    private var gardenHeader: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: GuozaiSpacing.medium) {
                    gardenBrand
                    Spacer(minLength: GuozaiSpacing.small)
                    progressBadge
                }

                VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
                    gardenBrand
                    progressBadge
                }
            }

            Text(currentStageTitle)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(GuozaiColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentTreeStatusText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GuozaiColor.inkMuted)
        }
    }

    private var gardenBrand: some View {
        HStack(spacing: GuozaiSpacing.small) {
            Image(systemName: "leaf.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GuozaiColor.leaf)
                .frame(width: 30, height: 30)
                .background(GuozaiColor.leafSoft.opacity(0.88), in: Circle())

            Text("果仔成长花园")
                .font(Font.custom("Kaiti SC", size: 25, relativeTo: .title2).weight(.bold))
                .foregroundStyle(GuozaiColor.oceanDeep)
        }
    }

    private var progressBadge: some View {
        HStack(alignment: .firstTextBaseline, spacing: GuozaiSpacing.xSmall) {
            Text("\(progress.currentTreeDay)")
                .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(GuozaiColor.oceanDeep)

            Text("/ \(GrowthGardenProgress.achievedDaysPerTree) 天")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(GuozaiColor.inkMuted)
        }
        .padding(.horizontal, GuozaiSpacing.medium)
        .frame(minHeight: 44)
        .background(GuozaiColor.paper.opacity(0.76), in: Capsule())
        .overlay {
            Capsule()
                .stroke(GuozaiColor.mango.opacity(0.34), lineWidth: 1)
        }
    }

    private var growthTrail: some View {
        VStack(spacing: GuozaiSpacing.xSmall) {
            HStack {
                Text("种下种子")
                Spacer()
                Text("结出果实")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(GuozaiColor.inkMuted)

            GardenGrowthTrail(fraction: progress.completionFraction)
        }
    }

    private var milestoneFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: GuozaiSpacing.medium) {
                nextStageHint
                Spacer(minLength: GuozaiSpacing.medium)
                completedTreeBadge
            }

            VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
                nextStageHint
                completedTreeBadge
            }
        }
    }

    private var nextStageHint: some View {
        HStack(alignment: .top, spacing: GuozaiSpacing.small) {
            Image(systemName: progress.currentTreeDay == GrowthGardenProgress.achievedDaysPerTree ? "checkmark" : "sun.max.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(GuozaiColor.oceanDeep)
                .frame(width: 28, height: 28)
                .background(GuozaiColor.mangoSoft.opacity(0.86), in: Circle())
                .accessibilityHidden(true)

            Text(nextStageText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GuozaiColor.oceanDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var completedTreeBadge: some View {
        if progress.completedTreeCount > 0 {
            Label("\(progress.completedTreeCount) 棵已长成", systemImage: "tree.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(GuozaiColor.leaf)
                .padding(.horizontal, GuozaiSpacing.small)
                .frame(minHeight: 30)
                .background(GuozaiColor.leafSoft.opacity(0.72), in: Capsule())
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var currentStageTitle: String {
        if progress.currentTreeDay == GrowthGardenProgress.achievedDaysPerTree {
            return "这棵果树已经长成"
        }
        return progress.stage.gardenTitle
    }

    private var currentTreeStatusText: String {
        if progress.currentTreeDay == GrowthGardenProgress.achievedDaysPerTree {
            return "第 \(progress.currentTreeNumber) 棵树已经长成"
        }
        return "第 \(progress.currentTreeNumber) 棵树正在生长"
    }

    private var nextStageText: String {
        if progress.currentTreeDay == 0 {
            return "完成一次今日计划，种子就会悄悄裂开。"
        }

        if progress.currentTreeDay == GrowthGardenProgress.achievedDaysPerTree {
            return "成长已经留在花园里，下一次达成会种下新种子。"
        }

        return "再达成 \(progress.daysUntilNextStage) 天，就会\(progress.stage.nextGrowthDescription)。"
    }

    private var accessibilitySummary: String {
        var parts = [
            "果仔成长花园",
            "第 \(progress.currentTreeNumber) 棵树",
            "当前第 \(progress.currentTreeDay) 天，共 \(GrowthGardenProgress.achievedDaysPerTree) 天",
            currentStageTitle,
            nextStageText
        ]

        if progress.completedTreeCount > 0 {
            parts.append("已经长成 \(progress.completedTreeCount) 棵树")
        }

        return parts.joined(separator: "。")
    }
}

private struct GardenGrowthTrail: View {
    let fraction: Double

    private var clampedFraction: CGFloat {
        CGFloat(min(1, max(0, fraction)))
    }

    var body: some View {
        GeometryReader { geometry in
            let markerSize: CGFloat = 18
            let trackHeight: CGFloat = 7
            let markerTravel = max(0, geometry.size.width - markerSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GuozaiColor.ink.opacity(0.09))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [GuozaiColor.leaf, GuozaiColor.mango],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * clampedFraction, height: trackHeight)

                Circle()
                    .fill(GuozaiColor.paper)
                    .overlay {
                        Circle()
                            .stroke(GuozaiColor.leaf, lineWidth: 1.5)
                    }
                    .overlay {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(GuozaiColor.leaf)
                    }
                    .frame(width: markerSize, height: markerSize)
                    .offset(x: markerTravel * clampedFraction)
                    .shadow(color: GuozaiColor.leaf.opacity(0.18), radius: 3, y: 1)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

private struct GardenPaperBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        GuozaiColor.paper,
                        GuozaiColor.mangoSoft.opacity(0.34),
                        GuozaiColor.leafSoft.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        GuozaiColor.mangoSoft.opacity(0.72),
                        GuozaiColor.mangoSoft.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.20
                )
                .frame(width: geometry.size.width * 0.44, height: geometry.size.width * 0.44)
                .offset(x: geometry.size.width * 0.10, y: -geometry.size.width * 0.16)

                Image(systemName: "leaf.fill")
                    .font(.system(size: max(96, geometry.size.width * 0.18), weight: .regular))
                    .foregroundStyle(GuozaiColor.leaf.opacity(0.035))
                    .rotationEffect(.degrees(24))
                    .offset(x: geometry.size.width * 0.04, y: geometry.size.height * 0.30)
                    .accessibilityHidden(true)
            }
        }
    }
}

private extension GrowthGardenStage {
    var gardenTitle: String {
        switch self {
        case .seed:
            "一颗种子，正在等你出发"
        case .crackedSeed:
            "种子已经悄悄裂开"
        case .sprout:
            "嫩芽已经钻出土壤"
        case .seedling:
            "小苗长出了两片新叶"
        case .strongSeedling:
            "小苗正在茁壮长高"
        case .youngTree:
            "枝干正变得有力量"
        case .leafyTree:
            "第一片树冠正在成形"
        case .flourishing:
            "枝叶正一天天丰盛"
        case .fruiting:
            "果树结出了金黄果实"
        }
    }

    var nextGrowthDescription: String {
        switch self {
        case .seed:
            "悄悄裂开"
        case .crackedSeed:
            "冒出一株嫩芽"
        case .sprout:
            "长出两片新叶"
        case .seedling:
            "长成一株茁壮小苗"
        case .strongSeedling:
            "长出结实的枝干"
        case .youngTree:
            "拥有第一片树冠"
        case .leafyTree:
            "变得枝繁叶茂"
        case .flourishing:
            "结出金黄果实"
        case .fruiting:
            "完整长成"
        }
    }
}

#Preview("iPhone 第 10 天") {
    GrowthGardenView(progress: GrowthGardenProgress(achievedDayCount: 10))
        .padding(GuozaiSpacing.medium)
        .frame(width: 393)
        .background(GuozaiColor.canvasWarm)
}

#Preview("iPad 第 23 天") {
    GrowthGardenView(progress: GrowthGardenProgress(achievedDayCount: 23))
        .padding(GuozaiSpacing.large)
        .frame(width: 834)
        .background(GuozaiColor.canvasWarm)
}

#Preview("辅助功能字号") {
    GrowthGardenView(progress: GrowthGardenProgress(achievedDayCount: 6))
        .padding(GuozaiSpacing.medium)
        .frame(width: 393)
        .background(GuozaiColor.canvasWarm)
        .environment(\.dynamicTypeSize, .accessibility3)
}
