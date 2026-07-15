import SwiftUI

struct CompletionPraiseMoment: Identifiable, Equatable {
    let id = UUID()
    let taskID: UUID
    let taskTitle: String
    let title: String
    let message: String
    let isDayAchieved: Bool
}

struct CompletionPraiseOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCelebrating = false

    let moment: CompletionPraiseMoment

    var body: some View {
        ZStack {
            if !reduceMotion {
                celebrationParticles
            }

            VStack(spacing: GuozaiSpacing.small) {
                Image("GuozaiMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: moment.isDayAchieved ? 132 : 116, height: moment.isDayAchieved ? 132 : 116)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(GuozaiColor.mango.opacity(0.45), lineWidth: 2)
                    }
                    .rotationEffect(.degrees(reduceMotion ? 0 : isCelebrating ? 3 : -8))
                    .scaleEffect(reduceMotion ? 1 : isCelebrating ? 1 : 0.72)
                    .offset(y: reduceMotion ? 0 : isCelebrating ? -3 : 12)

                Text(moment.title)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(GuozaiColor.ink)

                Text(moment.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GuozaiColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Label(moment.taskTitle, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GuozaiColor.oceanDeep)
                    .lineLimit(1)
                    .padding(.horizontal, GuozaiSpacing.medium)
                    .frame(minHeight: 32)
                    .background(GuozaiColor.oceanSoft, in: Capsule())
            }
            .padding(.horizontal, GuozaiSpacing.xLarge)
            .padding(.vertical, GuozaiSpacing.large)
            .frame(maxWidth: 340)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous)
                    .stroke(GuozaiColor.mango.opacity(moment.isDayAchieved ? 0.65 : 0.32), lineWidth: 1.5)
            }
            .shadow(color: GuozaiColor.ink.opacity(0.18), radius: 24, y: 10)
        }
        .padding(.horizontal, GuozaiSpacing.xLarge)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                isCelebrating = true
            }
        }
        .accessibilityHidden(true)
    }

    private var backgroundColor: Color {
        moment.isDayAchieved ? GuozaiColor.mangoSoft : GuozaiColor.paper
    }

    private var celebrationParticles: some View {
        ForEach(Array(Self.particles.enumerated()), id: \.offset) { index, particle in
            Image(systemName: particle.symbol)
                .font(.system(size: particle.size, weight: .bold))
                .foregroundStyle(particle.color)
                .scaleEffect(isCelebrating ? 1 : 0.2)
                .rotationEffect(.degrees(isCelebrating ? particle.rotation : 0))
                .offset(
                    x: isCelebrating ? particle.offset.width : 0,
                    y: isCelebrating ? particle.offset.height : 12
                )
                .opacity(isCelebrating ? 1 : 0)
                .animation(
                    .spring(response: 0.48, dampingFraction: 0.68)
                        .delay(Double(index) * 0.035),
                    value: isCelebrating
                )
        }
    }

    private struct Particle {
        let symbol: String
        let color: Color
        let size: CGFloat
        let offset: CGSize
        let rotation: Double
    }

    private static let particles: [Particle] = [
        Particle(symbol: "star.fill", color: GuozaiColor.mango, size: 22, offset: CGSize(width: -145, height: -90), rotation: -20),
        Particle(symbol: "sparkle", color: GuozaiColor.ocean, size: 20, offset: CGSize(width: 142, height: -102), rotation: 25),
        Particle(symbol: "heart.fill", color: GuozaiColor.coral, size: 17, offset: CGSize(width: -150, height: 34), rotation: -16),
        Particle(symbol: "star.fill", color: GuozaiColor.leaf, size: 16, offset: CGSize(width: 150, height: 38), rotation: 18),
        Particle(symbol: "sparkles", color: GuozaiColor.mango, size: 20, offset: CGSize(width: -104, height: 128), rotation: -10),
        Particle(symbol: "star.fill", color: GuozaiColor.coral, size: 14, offset: CGSize(width: 112, height: 130), rotation: 24)
    ]
}

#Preview("普通完成") {
    ZStack {
        GuozaiColor.canvasWarm.ignoresSafeArea()
        CompletionPraiseOverlay(
            moment: CompletionPraiseMoment(
                taskID: UUID(),
                taskTitle: "大声朗读或阅读 30 分钟",
                title: "果仔真棒！",
                message: "又向前迈了一小步！",
                isDayAchieved: false
            )
        )
    }
}

#Preview("今日达成") {
    ZStack {
        GuozaiColor.canvasWarm.ignoresSafeArea()
        CompletionPraiseOverlay(
            moment: CompletionPraiseMoment(
                taskID: UUID(),
                taskTitle: "户外运动 60 分钟",
                title: "今日达成！",
                message: "必做任务全部完成，今天的星星亮起来啦！",
                isDayAchieved: true
            )
        )
    }
}
