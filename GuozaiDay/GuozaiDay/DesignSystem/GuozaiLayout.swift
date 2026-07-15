import CoreGraphics

enum GuozaiSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 18
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
    static let hero: CGFloat = 48
}

enum GuozaiRadius {
    static let small: CGFloat = 7
    static let control: CGFloat = 11
    static let section: CGFloat = 18
}

enum GuozaiLayout {
    static let minimumTouchTarget: CGFloat = 52
    static let readableContentWidth: CGFloat = 1_080

    static let sidebarMinimumWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 248
    static let sidebarMaximumWidth: CGFloat = 292
}
