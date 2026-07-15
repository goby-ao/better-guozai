import SwiftUI

/// 把达成天数转译成不会消费的成长花园。
struct GrowthGardenView: View {
    let progress: GrowthGardenProgress

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(GuozaiSpacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GardenPaperBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous)
                .stroke(
                    GuozaiColor.line.opacity(colorSchemeContrast == .increased ? 0.95 : 0.58),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.75
                )
        }
        .shadow(color: GuozaiColor.leaf.opacity(0.10), radius: 14, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: GuozaiSpacing.xxLarge) {
            GrowthPlantIllustration(progress: progress)
                .frame(width: 320, height: 238)

            gardenDetails
                .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 650, maxWidth: .infinity, alignment: .leading)
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
            GrowthPlantIllustration(progress: progress)
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            gardenDetails
        }
    }

    private var gardenDetails: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            Label("果仔成长花园", systemImage: "leaf.fill")
                .font(Font.custom("Kaiti SC", size: 27, relativeTo: .title2).weight(.bold))
                .foregroundStyle(GuozaiColor.oceanDeep)

            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                Text(progress.stage.gardenTitle)
                    .guozaiTextStyle(.sectionTitle)
                    .foregroundStyle(GuozaiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(progress.stage.gardenDescription)
                    .guozaiTextStyle(.body)
                    .foregroundStyle(GuozaiColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            progressSummary
            GardenStepTrack(currentStep: progress.currentTreeDay)

            Label(completedTreeText, systemImage: progress.completedTreeCount > 0 ? "tree.fill" : "leaf")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            nextStageHint
        }
    }

    private var progressSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: GuozaiSpacing.large) {
                currentTreeLabel
                Spacer(minLength: GuozaiSpacing.small)
                currentStepLabel
            }

            VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
                currentTreeLabel
                currentStepLabel
            }
        }
    }

    private var currentTreeLabel: some View {
        Text("第 \(progress.currentTreeNumber) 棵树")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(GuozaiColor.leaf)
            .accessibilityLabel("正在培育第 \(progress.currentTreeNumber) 棵树")
    }

    private var currentStepLabel: some View {
        Text("第 \(progress.currentTreeDay)/\(GrowthGardenProgress.achievedDaysPerTree) 步")
            .font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
            .foregroundStyle(GuozaiColor.inkMuted)
            .accessibilityLabel(
                "当前成长到第 \(progress.currentTreeDay) 步，共 \(GrowthGardenProgress.achievedDaysPerTree) 步"
            )
    }

    private var nextStageHint: some View {
        HStack(alignment: .top, spacing: GuozaiSpacing.small) {
            Image(systemName: progress.daysUntilNextStage == 0 ? "checkmark" : "arrow.up.right")
                .font(.footnote.bold())
                .foregroundStyle(GuozaiColor.oceanDeep)
                .frame(width: 24, height: 24)
                .background(GuozaiColor.oceanSoft.opacity(0.78), in: Circle())
                .accessibilityHidden(true)

            Text(nextStageText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GuozaiColor.oceanDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, GuozaiSpacing.xSmall)
    }

    private var completedTreeText: String {
        if progress.completedTreeCount == 0 {
            return "第一棵树正在长大，长成以后会一直留在花园里。"
        }
        return "花园里已经有 \(progress.completedTreeCount) 棵完整的大树，它们会一直留下来。"
    }

    private var nextStageText: String {
        let days = progress.daysUntilNextStage

        if progress.stage == .flourishing {
            if days == 0 {
                return "这棵树已经长成，下一次达成会种下新的种子。"
            }
            return "再达成 \(days) 天，这棵树就会完整长成。"
        }

        return "再达成 \(days) 天，就会\(progress.stage.nextGrowthDescription)。"
    }
}

private struct GardenStepTrack: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...GrowthGardenProgress.achievedDaysPerTree, id: \.self) { step in
                Capsule()
                    .fill(color(for: step))
                    .frame(maxWidth: .infinity)
                    .frame(height: 7)
                    .scaleEffect(y: step == currentStep ? 1.35 : 1, anchor: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func color(for step: Int) -> Color {
        if step == currentStep, currentStep > 0 {
            return GuozaiColor.mango
        }
        if step < currentStep {
            return GuozaiColor.leaf.opacity(0.78)
        }
        return GuozaiColor.line.opacity(0.38)
    }
}

private struct GardenPaperBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                GuozaiColor.paper

                Circle()
                    .fill(GuozaiColor.mangoSoft.opacity(0.34))
                    .frame(width: geometry.size.width * 0.36)
                    .offset(x: geometry.size.width * 0.12, y: -geometry.size.width * 0.20)

                Circle()
                    .fill(GuozaiColor.leafSoft.opacity(0.28))
                    .frame(width: geometry.size.width * 0.44)
                    .offset(x: geometry.size.width * 0.18, y: geometry.size.height * 0.46)
            }
        }
    }
}

private extension GrowthGardenStage {
    var gardenTitle: String {
        switch self {
        case .seed:
            "一颗勇敢的小种子"
        case .sprout:
            "嫩芽钻出了土壤"
        case .seedling:
            "小苗长出了新叶"
        case .youngTree:
            "枝干正在变得有力量"
        case .leafyTree:
            "树冠一天天丰盛"
        case .flourishing:
            "这棵树正在枝繁叶茂"
        }
    }

    var gardenDescription: String {
        switch self {
        case .seed:
            "它会安静地等果仔开始，第一次今日达成就是破土的力量。"
        case .sprout:
            "第一份坚持已经破土，嫩芽正朝着光伸展。"
        case .seedling:
            "每天多一点认真，小苗就会多长出一点绿色。"
        case .youngTree:
            "根和枝干正在变稳，努力已经有了清楚的形状。"
        case .leafyTree:
            "枝叶越来越丰盛，这是一天一天积累出来的样子。"
        case .flourishing:
            "它已经枝繁叶茂，很快会成为花园里长久留下的一棵树。"
        }
    }

    var nextGrowthDescription: String {
        switch self {
        case .seed:
            "冒出第一片嫩芽"
        case .sprout:
            "长成一株小苗"
        case .seedling:
            "长出结实的枝干"
        case .youngTree:
            "拥有更丰盛的树冠"
        case .leafyTree:
            "变得枝繁叶茂"
        case .flourishing:
            "完整长成"
        }
    }
}

#Preview("刚刚种下") {
    GrowthGardenView(progress: GrowthGardenProgress(achievedDayCount: 0))
        .padding()
        .background(GuozaiColor.canvasWarm)
}

#Preview("枝繁叶茂") {
    GrowthGardenView(progress: GrowthGardenProgress(achievedDayCount: 26))
        .padding()
        .background(GuozaiColor.canvasWarm)
}
