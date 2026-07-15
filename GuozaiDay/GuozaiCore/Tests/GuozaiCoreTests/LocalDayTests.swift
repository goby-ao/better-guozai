import XCTest
@testable import GuozaiCore

final class LocalDayTests: XCTestCase {
    func testParsesStableDayKey() {
        XCTAssertEqual(
            LocalDay(key: "2026-07-14"),
            LocalDay(year: 2026, month: 7, day: 14)
        )
    }

    func testRejectsMalformedOrImpossibleDayKeys() {
        XCTAssertNil(LocalDay(key: "2026-7-14"))
        XCTAssertNil(LocalDay(key: "2026-02-29"))
        XCTAssertNil(LocalDay(key: "2026/07/14"))
    }

    func testCodableUsesStableDayKey() throws {
        let day = LocalDay(year: 2026, month: 7, day: 14)

        let data = try JSONEncoder().encode(day)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"2026-07-14\"")
        XCTAssertEqual(try JSONDecoder().decode(LocalDay.self, from: data), day)
    }
}
