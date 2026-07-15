import XCTest
@testable import GuozaiCore

final class DailyTaskSnapshotTests: XCTestCase {
    func testGeneratedTaskCopiesTemplateFieldsIntoHistoricalSnapshot() {
        let template = TaskTemplateSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "阅读 30 分钟",
            growthArea: .reading,
            tags: ["语文", "课外书"],
            requirement: .required,
            recurrence: RecurrenceRule(
                kind: .daily,
                start: LocalDay(year: 2026, month: 7, day: 1)
            ),
            target: QuantityTarget(amount: 30, unit: "分钟")
        )

        let task = DailyTaskSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            day: LocalDay(year: 2026, month: 7, day: 14),
            template: template
        )

        XCTAssertEqual(task.templateID, template.id)
        XCTAssertEqual(task.title, "阅读 30 分钟")
        XCTAssertEqual(task.growthArea, .reading)
        XCTAssertEqual(task.tags, ["语文", "课外书"])
        XCTAssertEqual(task.requirement, .required)
        XCTAssertEqual(task.target, QuantityTarget(amount: 30, unit: "分钟"))
        XCTAssertEqual(task.state, .pending)
    }
}
