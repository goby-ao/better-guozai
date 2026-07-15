import SwiftUI

/// 用于页面中的主要阅读区域。普通列表行不应套用此容器。
struct PaperSection<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let systemImage: String?
    private let compactDensity: Bool
    private let content: Content

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var compactBodySize: CGFloat = 14

    init(
        _ title: String? = nil,
        subtitle: String? = nil,
        systemImage: String? = nil,
        compactDensity: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.compactDensity = compactDensity
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.large) {
            if title != nil || subtitle != nil {
                header
            }

            content
        }
        .padding(usesCompactDensity ? GuozaiSpacing.medium : horizontalSizeClass == .compact ? GuozaiSpacing.large : GuozaiSpacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GuozaiColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GuozaiRadius.section, style: .continuous)
                .stroke(
                    GuozaiColor.line.opacity(colorSchemeContrast == .increased ? 0.95 : 0.58),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.75
                )
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
            if let title {
                HStack(spacing: GuozaiSpacing.small) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(GuozaiColor.ocean)
                            .accessibilityHidden(true)
                    }

                    sectionTitle(title)
                }
            }

            if let subtitle {
                sectionSubtitle(subtitle)
            }
        }
    }

    private var usesCompactDensity: Bool {
        compactDensity && horizontalSizeClass == .compact
    }

    @ViewBuilder
    private func sectionTitle(_ value: String) -> some View {
        if usesCompactDensity {
            Text(value)
                .font(Font.custom("Kaiti SC", size: 20, relativeTo: .title2).weight(.bold))
                .foregroundStyle(GuozaiColor.ink)
        } else {
            Text(value)
                .guozaiTextStyle(.sectionTitle)
                .foregroundStyle(GuozaiColor.ink)
        }
    }

    @ViewBuilder
    private func sectionSubtitle(_ value: String) -> some View {
        if usesCompactDensity {
            Text(value)
                .font(.system(size: compactBodySize))
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(value)
                .guozaiTextStyle(.body)
                .foregroundStyle(GuozaiColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
