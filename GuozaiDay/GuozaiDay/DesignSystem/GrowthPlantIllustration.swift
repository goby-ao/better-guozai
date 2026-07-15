import SwiftUI

/// 果仔成长花园的原生 SwiftUI 植物插画，可在成长页和完成鼓励中复用。
struct GrowthPlantIllustration: View {
    let progress: GrowthGardenProgress
    let compact: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: GrowthGardenProgress, compact: Bool = false) {
        self.progress = progress
        self.compact = compact
    }

    var body: some View {
        ZStack {
            GardenAtmosphere(compact: compact)

            ForEach(GrowthGardenStage.allCases, id: \.self) { stage in
                PlantStageArtwork(
                    stage: stage,
                    currentTreeDay: progress.currentTreeDay,
                    compact: compact
                )
                .opacity(stage == progress.stage ? 1 : 0)
                .scaleEffect(stage == progress.stage ? 1 : 0.96, anchor: .bottom)
                .offset(y: stage == progress.stage ? 0 : 8)
            }
        }
        .aspectRatio(compact ? 1.15 : 1.34, contentMode: .fit)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.5),
            value: progress.stage
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.5),
            value: progress.currentTreeDay
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GardenAtmosphere: View {
    let compact: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                Circle()
                    .fill(GuozaiColor.mangoSoft.opacity(compact ? 0.42 : 0.60))
                    .frame(width: width * 0.25, height: width * 0.25)
                    .position(x: width * 0.78, y: height * 0.20)

                Circle()
                    .fill(GuozaiColor.paper.opacity(0.80))
                    .frame(width: width * 0.12, height: width * 0.12)
                    .position(x: width * 0.78, y: height * 0.20)

                Ellipse()
                    .fill(GuozaiColor.leafSoft.opacity(compact ? 0.34 : 0.48))
                    .frame(width: width * 0.86, height: height * 0.56)
                    .position(x: width * 0.48, y: height * 0.60)
            }
        }
    }
}

private struct PlantStageArtwork: View {
    let stage: GrowthGardenStage
    let currentTreeDay: Int
    let compact: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                GardenGround(size: size)

                switch stage {
                case .seed:
                    SeedArtwork(size: size)
                case .sprout:
                    SproutArtwork(size: size, currentTreeDay: currentTreeDay)
                case .seedling:
                    SeedlingArtwork(size: size, currentTreeDay: currentTreeDay)
                case .youngTree, .leafyTree, .flourishing:
                    TreeArtwork(
                        size: size,
                        stage: stage,
                        currentTreeDay: currentTreeDay,
                        compact: compact
                    )
                }
            }
        }
    }
}

private struct GardenGround: View {
    let size: CGSize

    var body: some View {
        ZStack {
            Ellipse()
                .fill(GuozaiColor.leafSoft.opacity(0.82))
                .frame(width: size.width * 0.68, height: size.height * 0.14)
                .position(x: size.width * 0.50, y: size.height * 0.84)

            Ellipse()
                .fill(GuozaiColor.canvasWarm.opacity(0.92))
                .frame(width: size.width * 0.54, height: size.height * 0.085)
                .position(x: size.width * 0.50, y: size.height * 0.845)
        }
    }
}

private struct SeedArtwork: View {
    let size: CGSize

    var body: some View {
        SeedGlyph()
            .frame(width: size.width * 0.13, height: size.height * 0.14)
            .rotationEffect(.degrees(-13))
            .position(x: size.width * 0.50, y: size.height * 0.77)
    }
}

private struct SproutArtwork: View {
    let size: CGSize
    let currentTreeDay: Int

    var body: some View {
        ZStack {
            SeedGlyph()
                .frame(width: size.width * 0.11, height: size.height * 0.12)
                .rotationEffect(.degrees(-10))
                .position(x: size.width * 0.50, y: size.height * 0.79)

            Capsule()
                .fill(GuozaiColor.leaf)
                .frame(width: max(4, size.width * 0.016), height: size.height * 0.22)
                .rotationEffect(.degrees(2), anchor: .bottom)
                .position(x: size.width * 0.50, y: size.height * 0.68)

            PlantLeaf(color: GuozaiColor.leaf)
                .frame(width: size.width * 0.14, height: size.height * 0.105)
                .rotationEffect(.degrees(-43), anchor: .bottomTrailing)
                .position(x: size.width * 0.445, y: size.height * 0.60)

            PlantLeaf(color: GuozaiColor.leafSoft)
                .frame(width: size.width * 0.14, height: size.height * 0.105)
                .rotationEffect(.degrees(43), anchor: .bottomLeading)
                .position(x: size.width * 0.555, y: size.height * 0.57)
                .opacity(currentTreeDay >= 2 ? 1 : 0)
                .scaleEffect(currentTreeDay >= 2 ? 1 : 0.62, anchor: .bottomLeading)
                .offset(y: currentTreeDay >= 2 ? 0 : 5)
        }
    }
}

private struct SeedlingArtwork: View {
    let size: CGSize
    let currentTreeDay: Int

    private var visibleLeafCount: Int {
        min(Self.leaves.count, max(2, currentTreeDay - 1))
    }

    var body: some View {
        ZStack {
            SeedlingBranchShape()
                .stroke(
                    GuozaiColor.leaf,
                    style: StrokeStyle(
                        lineWidth: max(4, size.width * 0.018),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            ForEach(Self.leaves.indices, id: \.self) { index in
                let leaf = Self.leaves[index]
                let isVisible = index < visibleLeafCount

                PlantLeaf(color: index.isMultiple(of: 2) ? GuozaiColor.leaf : GuozaiColor.leafSoft)
                    .frame(width: size.width * leaf.width, height: size.height * leaf.height)
                    .rotationEffect(.degrees(leaf.rotation))
                    .position(x: size.width * leaf.x, y: size.height * leaf.y)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.66, anchor: .bottom)
                    .offset(y: isVisible ? 0 : 5)
            }
        }
    }

    private static let leaves: [LeafPlacement] = [
        .init(x: 0.44, y: 0.58, width: 0.14, height: 0.10, rotation: -48),
        .init(x: 0.56, y: 0.52, width: 0.14, height: 0.10, rotation: 44),
        .init(x: 0.43, y: 0.46, width: 0.13, height: 0.095, rotation: -38),
        .init(x: 0.57, y: 0.40, width: 0.13, height: 0.095, rotation: 40),
        .init(x: 0.50, y: 0.34, width: 0.12, height: 0.09, rotation: 4)
    ]
}

private struct TreeArtwork: View {
    let size: CGSize
    let stage: GrowthGardenStage
    let currentTreeDay: Int
    let compact: Bool

    private var maturity: Int {
        switch stage {
        case .youngTree: 0
        case .leafyTree: 1
        case .flourishing: 2
        default: 0
        }
    }

    private var visibleCanopyCount: Int {
        switch stage {
        case .youngTree:
            min(Self.canopy.count, max(2, currentTreeDay - 5))
        case .leafyTree:
            min(Self.canopy.count, max(8, currentTreeDay - 6))
        case .flourishing:
            Self.canopy.count
        default:
            0
        }
    }

    private var visibleAccentLeafCount: Int {
        guard stage == .flourishing else { return 0 }
        return min(Self.accentLeaves.count, max(1, currentTreeDay - 20))
    }

    private var visibleFruitCount: Int {
        guard stage == .flourishing else { return 0 }
        return min(Self.fruits.count, max(0, (currentTreeDay - 22) / 2))
    }

    private var trunkHeight: CGFloat {
        size.height * (0.38 + CGFloat(maturity) * 0.06)
    }

    private var trunkCenterY: CGFloat {
        size.height * (0.65 - CGFloat(maturity) * 0.03)
    }

    private var canopyScale: CGFloat {
        0.88 + CGFloat(maturity) * 0.08
    }

    var body: some View {
        ZStack {
            TreeBranchShape(maturity: maturity)
                .stroke(
                    GuozaiColor.coral.opacity(0.88),
                    style: StrokeStyle(
                        lineWidth: compact ? max(3, size.width * 0.014) : max(4, size.width * 0.016),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            TaperedTrunkShape()
                .fill(GuozaiColor.coral.opacity(0.94))
                .overlay {
                    TaperedTrunkShape()
                        .stroke(GuozaiColor.ink.opacity(0.12), lineWidth: 1)
                }
                .frame(
                    width: size.width * (0.085 + CGFloat(maturity) * 0.012),
                    height: trunkHeight
                )
                .position(x: size.width * 0.50, y: trunkCenterY)

            ForEach(Self.canopy.indices, id: \.self) { index in
                let cluster = Self.canopy[index]
                let isVisible = index < visibleCanopyCount

                CanopyCluster(
                    primary: index.isMultiple(of: 3) ? GuozaiColor.leafSoft : GuozaiColor.leaf,
                    secondary: index.isMultiple(of: 3) ? GuozaiColor.leaf : GuozaiColor.leafSoft
                )
                .frame(
                    width: size.width * cluster.width * canopyScale,
                    height: size.height * cluster.height * canopyScale
                )
                .position(x: size.width * cluster.x, y: size.height * cluster.y)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.72, anchor: .bottom)
                .offset(y: isVisible ? 0 : 6)
            }

            ForEach(Self.accentLeaves.indices, id: \.self) { index in
                let leaf = Self.accentLeaves[index]
                let isVisible = index < visibleAccentLeafCount

                PlantLeaf(color: index.isMultiple(of: 2) ? GuozaiColor.leaf : GuozaiColor.leafSoft)
                    .frame(width: size.width * leaf.width, height: size.height * leaf.height)
                    .rotationEffect(.degrees(leaf.rotation))
                    .position(x: size.width * leaf.x, y: size.height * leaf.y)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.62, anchor: .bottom)
                    .offset(y: isVisible ? 0 : 5)
            }

            ForEach(Self.fruits.indices, id: \.self) { index in
                let fruit = Self.fruits[index]
                let isVisible = index < visibleFruitCount

                Circle()
                    .fill(GuozaiColor.mango)
                    .overlay {
                        Circle().stroke(GuozaiColor.paper.opacity(0.70), lineWidth: 1)
                    }
                    .frame(width: size.width * 0.035, height: size.width * 0.035)
                    .position(x: size.width * fruit.x, y: size.height * fruit.y)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .offset(y: isVisible ? 0 : 5)
            }
        }
    }

    private static let canopy: [CanopyPlacement] = [
        .init(x: 0.50, y: 0.35, width: 0.21, height: 0.17),
        .init(x: 0.41, y: 0.39, width: 0.20, height: 0.16),
        .init(x: 0.59, y: 0.39, width: 0.20, height: 0.16),
        .init(x: 0.50, y: 0.45, width: 0.22, height: 0.17),
        .init(x: 0.33, y: 0.43, width: 0.20, height: 0.16),
        .init(x: 0.67, y: 0.43, width: 0.20, height: 0.16),
        .init(x: 0.39, y: 0.31, width: 0.20, height: 0.16),
        .init(x: 0.61, y: 0.31, width: 0.20, height: 0.16),
        .init(x: 0.28, y: 0.49, width: 0.19, height: 0.15),
        .init(x: 0.72, y: 0.49, width: 0.19, height: 0.15),
        .init(x: 0.50, y: 0.25, width: 0.20, height: 0.16),
        .init(x: 0.31, y: 0.34, width: 0.18, height: 0.15),
        .init(x: 0.69, y: 0.34, width: 0.18, height: 0.15),
        .init(x: 0.50, y: 0.53, width: 0.21, height: 0.16)
    ]

    private static let accentLeaves: [LeafPlacement] = [
        .init(x: 0.23, y: 0.40, width: 0.09, height: 0.067, rotation: -58),
        .init(x: 0.77, y: 0.39, width: 0.09, height: 0.067, rotation: 58),
        .init(x: 0.35, y: 0.22, width: 0.085, height: 0.063, rotation: -26),
        .init(x: 0.65, y: 0.22, width: 0.085, height: 0.063, rotation: 26),
        .init(x: 0.23, y: 0.53, width: 0.085, height: 0.063, rotation: -72),
        .init(x: 0.77, y: 0.53, width: 0.085, height: 0.063, rotation: 72),
        .init(x: 0.44, y: 0.16, width: 0.08, height: 0.06, rotation: -12),
        .init(x: 0.56, y: 0.16, width: 0.08, height: 0.06, rotation: 12)
    ]

    private static let fruits: [PointPlacement] = [
        .init(x: 0.39, y: 0.38),
        .init(x: 0.61, y: 0.42),
        .init(x: 0.51, y: 0.29)
    ]
}

private struct SeedGlyph: View {
    var body: some View {
        ZStack {
            SeedShape()
                .fill(GuozaiColor.coral.opacity(0.92))

            SeedShape()
                .stroke(GuozaiColor.ink.opacity(0.18), lineWidth: 1)

            Capsule()
                .fill(GuozaiColor.paper.opacity(0.42))
                .frame(width: 3, height: 18)
                .rotationEffect(.degrees(18))
                .offset(x: -3, y: -2)
        }
    }
}

private struct PlantLeaf: View {
    let color: Color

    var body: some View {
        ZStack {
            LeafShape()
                .fill(color)

            LeafVeinShape()
                .stroke(GuozaiColor.paper.opacity(0.58), lineWidth: 1)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
        }
    }
}

private struct CanopyCluster: View {
    let primary: Color
    let secondary: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let unit = min(width, height)

            ZStack {
                Ellipse()
                    .fill(primary.opacity(0.95))
                    .frame(width: width * 0.86, height: height * 0.82)
                    .position(x: width * 0.50, y: height * 0.54)

                Circle()
                    .fill(secondary.opacity(0.94))
                    .frame(width: unit * 0.78, height: unit * 0.78)
                    .position(x: width * 0.32, y: height * 0.59)

                Circle()
                    .fill(primary)
                    .frame(width: unit * 0.72, height: unit * 0.72)
                    .position(x: width * 0.68, y: height * 0.41)

                Circle()
                    .fill(GuozaiColor.paper.opacity(0.18))
                    .frame(width: unit * 0.23, height: unit * 0.23)
                    .position(x: width * 0.46, y: height * 0.28)
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }
}

private struct SeedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX - rect.width * 0.05, y: rect.height * 0.20),
            control2: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.height * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.height * 0.82),
            control2: CGPoint(x: rect.maxX + rect.width * 0.05, y: rect.height * 0.20)
        )
        path.closeSubpath()
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.78),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.78)
        )
        path.closeSubpath()
        return path
    }
}

private struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18),
            control: CGPoint(x: rect.midX - rect.width * 0.10, y: rect.midY)
        )
        return path
    }
}

private struct SeedlingBranchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.80))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * 0.34),
            control1: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.height * 0.66),
            control2: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.height * 0.49)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.58))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.43, y: rect.height * 0.50),
            control: CGPoint(x: rect.width * 0.47, y: rect.height * 0.54)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.51))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.57, y: rect.height * 0.43),
            control: CGPoint(x: rect.width * 0.54, y: rect.height * 0.47)
        )
        return path
    }
}

private struct TreeBranchShape: Shape {
    let maturity: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.79))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * (maturity == 0 ? 0.35 : 0.25)),
            control1: CGPoint(x: rect.width * 0.52, y: rect.height * 0.62),
            control2: CGPoint(x: rect.width * 0.48, y: rect.height * 0.42)
        )

        addBranch(
            to: &path,
            from: CGPoint(x: 0.50, y: 0.60),
            control: CGPoint(x: 0.43, y: 0.52),
            end: CGPoint(x: 0.34, y: 0.43),
            in: rect
        )
        addBranch(
            to: &path,
            from: CGPoint(x: 0.50, y: 0.54),
            control: CGPoint(x: 0.57, y: 0.47),
            end: CGPoint(x: 0.66, y: 0.39),
            in: rect
        )

        if maturity >= 1 {
            addBranch(
                to: &path,
                from: CGPoint(x: 0.49, y: 0.48),
                control: CGPoint(x: 0.39, y: 0.40),
                end: CGPoint(x: 0.28, y: 0.35),
                in: rect
            )
            addBranch(
                to: &path,
                from: CGPoint(x: 0.50, y: 0.43),
                control: CGPoint(x: 0.59, y: 0.35),
                end: CGPoint(x: 0.72, y: 0.34),
                in: rect
            )
        }

        if maturity >= 2 {
            addBranch(
                to: &path,
                from: CGPoint(x: 0.50, y: 0.38),
                control: CGPoint(x: 0.44, y: 0.29),
                end: CGPoint(x: 0.38, y: 0.22),
                in: rect
            )
            addBranch(
                to: &path,
                from: CGPoint(x: 0.50, y: 0.35),
                control: CGPoint(x: 0.56, y: 0.27),
                end: CGPoint(x: 0.63, y: 0.20),
                in: rect
            )
        }

        return path
    }

    private func addBranch(
        to path: inout Path,
        from: CGPoint,
        control: CGPoint,
        end: CGPoint,
        in rect: CGRect
    ) {
        path.move(to: point(from, in: rect))
        path.addQuadCurve(to: point(end, in: rect), control: point(control, in: rect))
    }

    private func point(_ normalizedPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + normalizedPoint.x * rect.width,
            y: rect.minY + normalizedPoint.y * rect.height
        )
    }
}

private struct TaperedTrunkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.minY),
            control1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.height * 0.66),
            control2: CGPoint(x: rect.midX - rect.width * 0.24, y: rect.height * 0.30)
        )
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + rect.width * 0.24, y: rect.height * 0.30),
            control2: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.height * 0.66)
        )
        path.closeSubpath()
        return path
    }
}

private struct LeafPlacement {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
}

private struct CanopyPlacement {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private struct PointPlacement {
    let x: CGFloat
    let y: CGFloat
}
