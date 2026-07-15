import XCTest
@testable import GuozaiCore

final class MonthGridLayoutPolicyTests: XCTestCase {
    func testIPhone14ProContentWidthFitsAllSevenColumns() {
        let policy = MonthGridLayoutPolicy(isCompactWidth: true)
        let metrics = policy.metrics(availableWidth: 321)

        XCTAssertEqual(metrics.columnCount, 7)
        XCTAssertLessThanOrEqual(metrics.totalWidth, 321.001)
        XCTAssertGreaterThan(metrics.cellWidth, 40)
    }

    func testSmallestSupportedCompactWidthStillFits() {
        let policy = MonthGridLayoutPolicy(isCompactWidth: true)
        let metrics = policy.metrics(availableWidth: 248)

        XCTAssertEqual(metrics.cellWidth, 32, accuracy: 0.001)
        XCTAssertLessThanOrEqual(metrics.totalWidth, 248.001)
    }

    func testRegularWidthFillsAvailableWidth() {
        let policy = MonthGridLayoutPolicy(isCompactWidth: false)
        let metrics = policy.metrics(availableWidth: 900)

        XCTAssertEqual(metrics.cellWidth, 124.285, accuracy: 0.001)
        XCTAssertEqual(metrics.spacing, 5, accuracy: 0.001)
        XCTAssertEqual(metrics.totalWidth, 900, accuracy: 0.001)
    }
}
