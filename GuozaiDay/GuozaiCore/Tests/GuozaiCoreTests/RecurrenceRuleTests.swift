import XCTest
@testable import GuozaiCore

final class RecurrenceRuleTests: XCTestCase {
    func testDailyRuleAppliesEveryDay() {
        let rule = RecurrenceRule(
            kind: .daily,
            start: LocalDay(year: 2026, month: 7, day: 1)
        )

        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 12)))
        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 13)))
    }

    func testWeekdayRuleIncludesMondayAndExcludesSunday() {
        let rule = RecurrenceRule(
            kind: .weekdays,
            start: LocalDay(year: 2026, month: 7, day: 1)
        )

        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 13)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 12)))
    }

    func testWeekendRuleIncludesSundayAndExcludesMonday() {
        let rule = RecurrenceRule(
            kind: .weekends,
            start: LocalDay(year: 2026, month: 7, day: 1)
        )

        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 12)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 13)))
    }

    func testCustomRuleAppliesOnlyToSelectedWeekdays() {
        let rule = RecurrenceRule(
            kind: .custom,
            start: LocalDay(year: 2026, month: 7, day: 1),
            weekdays: [3, 5]
        )

        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 14)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 15)))
        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 16)))
    }

    func testStartAndEndDatesAreInclusive() {
        let rule = RecurrenceRule(
            kind: .daily,
            start: LocalDay(year: 2026, month: 7, day: 10),
            end: LocalDay(year: 2026, month: 7, day: 12)
        )

        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 9)))
        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 10)))
        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 12)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 13)))
    }

    func testPauseIntervalSuppressesGenerationInclusively() {
        let rule = RecurrenceRule(
            kind: .daily,
            start: LocalDay(year: 2026, month: 7, day: 1),
            pauses: [
                .init(
                    start: LocalDay(year: 2026, month: 7, day: 10),
                    end: LocalDay(year: 2026, month: 7, day: 12)
                )
            ]
        )

        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 9)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 10)))
        XCTAssertFalse(rule.applies(to: LocalDay(year: 2026, month: 7, day: 12)))
        XCTAssertTrue(rule.applies(to: LocalDay(year: 2026, month: 7, day: 13)))
    }

    func testUpcomingDaysRespectStartEndPauseAndLimit() {
        let rule = RecurrenceRule(
            kind: .daily,
            start: LocalDay(year: 2026, month: 7, day: 10),
            end: LocalDay(year: 2026, month: 7, day: 16),
            pauses: [
                .init(
                    start: LocalDay(year: 2026, month: 7, day: 12),
                    end: LocalDay(year: 2026, month: 7, day: 13)
                )
            ]
        )

        XCTAssertEqual(
            rule.upcomingDays(
                from: LocalDay(year: 2026, month: 7, day: 8),
                limit: 4
            ),
            [
                LocalDay(year: 2026, month: 7, day: 10),
                LocalDay(year: 2026, month: 7, day: 11),
                LocalDay(year: 2026, month: 7, day: 14),
                LocalDay(year: 2026, month: 7, day: 15),
            ]
        )
    }

    func testUpcomingDaysStopAtSearchHorizon() {
        let rule = RecurrenceRule(
            kind: .daily,
            start: LocalDay(year: 2027, month: 1, day: 1)
        )

        XCTAssertTrue(rule.upcomingDays(
            from: LocalDay(year: 2026, month: 7, day: 14),
            limit: 2,
            searchHorizonDays: 30
        ).isEmpty)
    }
}
