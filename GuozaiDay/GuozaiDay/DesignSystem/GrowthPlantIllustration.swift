import SwiftUI
import UIKit

private enum GrowthJourneyAsset {
    static let name = "GrowthJourney"
    static let pixelWidth = 2_172
    static let pixelHeight = 724
    static let aspectRatio = CGFloat(pixelWidth) / CGFloat(pixelHeight)

    static var validatedImage: UIImage? {
        guard
            let image = UIImage(named: name),
            let source = image.cgImage,
            source.width == pixelWidth,
            source.height == pixelHeight
        else {
            return nil
        }

        return image
    }
}

/// The generated growth journey is the shared visual source for the garden and
/// the compact completion celebration.
struct GrowthJourneyArtwork: View {
    let progress: GrowthGardenProgress

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedFraction: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                currentStageGlow(in: size)

                journeyImage
                    .saturation(0.06)
                    .opacity(0.22)

                journeyImage
                    .shadow(color: GuozaiColor.leaf.opacity(0.12), radius: 3, y: 2)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .scaleEffect(
                                x: max(0.001, revealedFraction),
                                y: 1,
                                anchor: .leading
                            )
                    }
            }
        }
        .aspectRatio(Self.assetAspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear(perform: updateReveal)
        .onChange(of: progress.stage) { _, _ in
            updateReveal()
        }
    }

    @ViewBuilder
    private var journeyImage: some View {
        if let image = GrowthJourneyAsset.validatedImage {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
        } else {
            Image(systemName: "leaf.fill")
                .resizable()
                .scaledToFit()
                .padding(.vertical, GuozaiSpacing.large)
                .foregroundStyle(GuozaiColor.leaf)
        }
    }

    private func currentStageGlow(in size: CGSize) -> some View {
        let diameter = min(size.height * 0.78, size.width * 0.13)

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        GuozaiColor.mangoSoft.opacity(0.78),
                        GuozaiColor.mangoSoft.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.5
                )
            )
            .frame(width: diameter, height: diameter)
            .position(
                x: size.width * progress.stage.journeyGeometry.centerX,
                y: size.height * progress.stage.journeyGeometry.glowY
            )
            .scaleEffect(revealedFraction > 0 ? 1 : 0.76)
            .opacity(revealedFraction > 0 ? 1 : 0)
    }

    private func updateReveal() {
        let target = progress.stage.journeyGeometry.revealX

        guard !reduceMotion else {
            revealedFraction = target
            return
        }

        withAnimation(.easeOut(duration: 0.55)) {
            revealedFraction = target
        }
    }

    static let assetAspectRatio = GrowthJourneyAsset.aspectRatio
}

/// A single-stage crop retained for the task-completion praise overlay.
struct GrowthPlantIllustration: View {
    let progress: GrowthGardenProgress
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                GuozaiColor.mangoSoft.opacity(compact ? 0.72 : 0.58),
                                GuozaiColor.leafSoft.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: min(geometry.size.width, geometry.size.height) * 0.54
                        )
                    )
                    .frame(
                        width: min(geometry.size.width, geometry.size.height) * 1.08,
                        height: min(geometry.size.width, geometry.size.height) * 1.08
                    )

                GrowthJourneyStageCrop(stage: progress.stage)
                    .padding(.vertical, compact ? 2 : GuozaiSpacing.small)
                    .shadow(color: GuozaiColor.leaf.opacity(0.14), radius: compact ? 2 : 4, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GrowthJourneyStageCrop: View {
    let stage: GrowthGardenStage

    var body: some View {
        Group {
            if let image = croppedStageImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(GuozaiSpacing.large)
                    .foregroundStyle(GuozaiColor.leaf)
            }
        }
    }

    private var croppedStageImage: UIImage? {
        guard
            let sourceImage = GrowthJourneyAsset.validatedImage,
            let source = sourceImage.cgImage
        else {
            return nil
        }

        let sourceSize = CGSize(width: CGFloat(source.width), height: CGFloat(source.height))
        let normalizedCrop = stage.journeyGeometry.cropRect
        let cropRect = CGRect(
            x: normalizedCrop.minX * sourceSize.width,
            y: normalizedCrop.minY * sourceSize.height,
            width: normalizedCrop.width * sourceSize.width,
            height: normalizedCrop.height * sourceSize.height
        )
        .integral
        .intersection(CGRect(origin: .zero, size: sourceSize))

        guard let cropped = source.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: sourceImage.scale, orientation: .up)
    }
}

private struct GrowthJourneyStageGeometry {
    let centerX: CGFloat
    let glowY: CGFloat
    let revealX: CGFloat
    let cropRect: CGRect

    init(centerX: CGFloat, glowY: CGFloat, revealX: CGFloat, cropRect: CGRect) {
        self.centerX = centerX
        self.glowY = glowY
        self.revealX = revealX
        self.cropRect = cropRect
            .insetBy(dx: -0.008, dy: -0.024)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

private extension GrowthGardenStage {
    /// Positions and alpha bounds measured from the generated panoramic asset.
    /// Keep this table synchronized with `GrowthJourneyAsset` when replacing it.
    var journeyGeometry: GrowthJourneyStageGeometry {
        switch self {
        case .seed:
            GrowthJourneyStageGeometry(
                centerX: 0.0589,
                glowY: 0.782,
                revealX: 0.1031,
                cropRect: CGRect(x: 0.0147, y: 0.7086, width: 0.0884, height: 0.1464)
            )
        case .crackedSeed:
            GrowthJourneyStageGeometry(
                centerX: 0.1607,
                glowY: 0.780,
                revealX: 0.2040,
                cropRect: CGRect(x: 0.1174, y: 0.7030, width: 0.0866, height: 0.1533)
            )
        case .sprout:
            GrowthJourneyStageGeometry(
                centerX: 0.2505,
                glowY: 0.733,
                revealX: 0.2855,
                cropRect: CGRect(x: 0.2155, y: 0.6105, width: 0.0700, height: 0.2445)
            )
        case .seedling:
            GrowthJourneyStageGeometry(
                centerX: 0.3439,
                glowY: 0.700,
                revealX: 0.3854,
                cropRect: CGRect(x: 0.3025, y: 0.5428, width: 0.0829, height: 0.3150)
            )
        case .strongSeedling:
            GrowthJourneyStageGeometry(
                centerX: 0.4583,
                glowY: 0.632,
                revealX: 0.5120,
                cropRect: CGRect(x: 0.4047, y: 0.4061, width: 0.1073, height: 0.4517)
            )
        case .youngTree:
            GrowthJourneyStageGeometry(
                centerX: 0.5665,
                glowY: 0.590,
                revealX: 0.6119,
                cropRect: CGRect(x: 0.5212, y: 0.3246, width: 0.0907, height: 0.5318)
            )
        case .leafyTree:
            GrowthJourneyStageGeometry(
                centerX: 0.6687,
                glowY: 0.612,
                revealX: 0.7196,
                cropRect: CGRect(x: 0.6179, y: 0.3674, width: 0.1017, height: 0.4890)
            )
        case .flourishing:
            GrowthJourneyStageGeometry(
                centerX: 0.7802,
                glowY: 0.579,
                revealX: 0.8347,
                cropRect: CGRect(x: 0.7256, y: 0.3025, width: 0.1091, height: 0.5539)
            )
        case .fruiting:
            GrowthJourneyStageGeometry(
                centerX: 0.9130,
                glowY: 0.550,
                revealX: 1,
                cropRect: CGRect(x: 0.8389, y: 0.2431, width: 0.1483, height: 0.6146)
            )
        }
    }
}

#Preview("成长旅程") {
    VStack(spacing: 28) {
        GrowthJourneyArtwork(progress: GrowthGardenProgress(achievedDayCount: 18))
        GrowthPlantIllustration(
            progress: GrowthGardenProgress(achievedDayCount: 28),
            compact: true
        )
        .frame(width: 176, height: 132)
    }
    .padding()
    .background(GuozaiColor.paper)
}
