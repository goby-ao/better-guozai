import SwiftUI

struct PrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let expandsHorizontally: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        expandsHorizontally: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.expandsHorizontally = expandsHorizontally
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: GuozaiSpacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(GuozaiPrimaryButtonStyle(expandsHorizontally: expandsHorizontally))
        .accessibilityLabel(Text(title))
    }
}

private struct GuozaiPrimaryButtonStyle: ButtonStyle {
    let expandsHorizontally: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .guozaiTextStyle(.control)
            .multilineTextAlignment(.center)
            .foregroundStyle(GuozaiColor.paper.opacity(isEnabled ? 1 : 0.82))
            .padding(.horizontal, GuozaiSpacing.large)
            .frame(
                maxWidth: expandsHorizontally ? .infinity : nil,
                minHeight: GuozaiLayout.minimumTouchTarget
            )
            .background {
                RoundedRectangle(cornerRadius: GuozaiRadius.control, style: .continuous)
                    .fill(isEnabled ? GuozaiColor.oceanDeep : GuozaiColor.inkMuted.opacity(0.48))
            }
            .contentShape(RoundedRectangle(cornerRadius: GuozaiRadius.control, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.92 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
