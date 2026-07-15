public struct TodayLayoutPolicy: Equatable, Sendable {
    public let usesCondensedHeader: Bool
    public let placesTargetInline: Bool
    public let showsPlanSubtitle: Bool

    public init(isCompactWidth: Bool) {
        usesCondensedHeader = isCompactWidth
        placesTargetInline = true
        showsPlanSubtitle = !isCompactWidth
    }
}
