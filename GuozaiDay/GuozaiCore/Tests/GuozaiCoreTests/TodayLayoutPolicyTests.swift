import XCTest
@testable import GuozaiCore

final class TodayLayoutPolicyTests: XCTestCase {
    func testCompactWidthUsesCondensedHeaderAndInlineTarget() {
        let policy = TodayLayoutPolicy(isCompactWidth: true)

        XCTAssertTrue(policy.usesCondensedHeader)
        XCTAssertTrue(policy.placesTargetInline)
        XCTAssertFalse(policy.showsPlanSubtitle)
    }

    func testRegularWidthKeepsHeroHeaderButTargetRemainsInline() {
        let policy = TodayLayoutPolicy(isCompactWidth: false)

        XCTAssertFalse(policy.usesCondensedHeader)
        XCTAssertTrue(policy.placesTargetInline)
        XCTAssertTrue(policy.showsPlanSubtitle)
    }
}
