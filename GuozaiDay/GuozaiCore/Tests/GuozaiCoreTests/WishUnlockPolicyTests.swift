import XCTest
@testable import GuozaiCore

final class WishUnlockPolicyTests: XCTestCase {
    func testSelectedWeeklyWishUnlocksAtTarget() {
        XCTAssertTrue(WishUnlockPolicy.isSatisfied(
            linkedBadgeSatisfied: false,
            weeklyTarget: 5,
            isSelectedWeeklyWish: true,
            achievedDayCount: 5
        ))
    }

    func testUnselectedWeeklyWishStaysLockedAtTarget() {
        XCTAssertFalse(WishUnlockPolicy.isSatisfied(
            linkedBadgeSatisfied: false,
            weeklyTarget: 5,
            isSelectedWeeklyWish: false,
            achievedDayCount: 7
        ))
    }

    func testBadgeLinkedWishDoesNotRequireSelection() {
        XCTAssertTrue(WishUnlockPolicy.isSatisfied(
            linkedBadgeSatisfied: true,
            weeklyTarget: nil,
            isSelectedWeeklyWish: false,
            achievedDayCount: 0
        ))
    }

    func testSelectedWishStaysLockedBeforeWeeklyTarget() {
        XCTAssertFalse(WishUnlockPolicy.isSatisfied(
            linkedBadgeSatisfied: false,
            weeklyTarget: 5,
            isSelectedWeeklyWish: true,
            achievedDayCount: 4
        ))
    }
}
