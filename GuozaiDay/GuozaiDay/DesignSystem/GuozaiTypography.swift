import SwiftUI

enum GuozaiTextRole {
    case pageTitle
    case sectionTitle
    case task
    case body
    case supporting
    case control
    case dateNumber
}

private struct GuozaiTextStyleModifier: ViewModifier {
    let role: GuozaiTextRole

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ScaledMetric(relativeTo: .title3) private var regularTaskSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var compactTaskSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var regularBodySize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var compactBodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .largeTitle) private var dateNumberSize: CGFloat = 34

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var font: Font {
        switch role {
        case .pageTitle:
            return Font.custom(
                "Kaiti SC",
                size: isCompact ? 34 : 40,
                relativeTo: .largeTitle
            )
            .weight(.bold)
        case .sectionTitle:
            return Font.custom(
                "Kaiti SC",
                size: isCompact ? 24 : 28,
                relativeTo: .title2
            )
            .weight(.bold)
        case .task:
            return .system(
                size: isCompact ? compactTaskSize : regularTaskSize,
                weight: .semibold,
                design: .rounded
            )
        case .body:
            return .system(
                size: isCompact ? compactBodySize : regularBodySize,
                weight: .regular,
                design: .default
            )
        case .supporting:
            return .footnote.weight(.semibold)
        case .control:
            return .system(.body, design: .rounded, weight: .bold)
        case .dateNumber:
            return .system(size: dateNumberSize, weight: .bold, design: .rounded).monospacedDigit()
        }
    }

    func body(content: Content) -> some View {
        content.font(font)
    }
}

private struct GuozaiScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat

    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _scaledSize = ScaledMetric(
            wrappedValue: size,
            relativeTo: Self.relativeStyle(for: size)
        )
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }

    private static func relativeStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...13: .caption
        case ...15: .footnote
        case ...18: .body
        case ...20: .title3
        case ...23: .title2
        case ...28: .title
        default: .largeTitle
        }
    }
}

extension View {
    func guozaiTextStyle(_ role: GuozaiTextRole) -> some View {
        modifier(GuozaiTextStyleModifier(role: role))
    }

    func guozaiScaledSystemFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(GuozaiScaledSystemFontModifier(size: size, weight: weight, design: design))
    }
}
