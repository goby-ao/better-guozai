public struct MonthGridLayoutPolicy: Equatable, Sendable {
    public struct Metrics: Equatable, Sendable {
        public let columnCount: Int
        public let cellWidth: Double
        public let spacing: Double

        public var totalWidth: Double {
            cellWidth * Double(columnCount) + spacing * Double(columnCount - 1)
        }
    }

    private let isCompactWidth: Bool

    public init(isCompactWidth: Bool) {
        self.isCompactWidth = isCompactWidth
    }

    public func metrics(availableWidth: Double) -> Metrics {
        let columnCount = 7
        let spacing = isCompactWidth ? 4.0 : 5.0
        let preferredCellWidth = 52.0
        let spacingWidth = spacing * Double(columnCount - 1)
        let fittingCellWidth = (max(availableWidth, spacingWidth) - spacingWidth) / Double(columnCount)
        let cellWidth = isCompactWidth
            ? min(preferredCellWidth, fittingCellWidth)
            : fittingCellWidth

        return Metrics(columnCount: columnCount, cellWidth: cellWidth, spacing: spacing)
    }
}
