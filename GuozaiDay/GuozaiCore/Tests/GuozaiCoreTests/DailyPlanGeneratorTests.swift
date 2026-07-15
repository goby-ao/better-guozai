import XCTest
@testable import GuozaiCore

final class DailyPlanGeneratorTests: XCTestCase {
    func testReturnsTemplateThatAppliesToRequestedDay() {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let templateID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let template = TaskTemplateSnapshot(
            id: templateID,
            profileID: profileID,
            title: "阅读",
            growthArea: .reading,
            requirement: .required,
            recurrence: RecurrenceRule(kind: .daily, start: day)
        )

        let missing = DailyPlanGenerator.missingTemplates(
            for: day,
            templates: [template],
            existingTasks: []
        )

        XCTAssertEqual(missing.map(\.id), [templateID])
    }

    func testExcludesTemplateThatDoesNotApplyToRequestedDay() {
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let template = makeTemplate(
            recurrence: RecurrenceRule(
                kind: .weekends,
                start: LocalDay(year: 2026, month: 7, day: 1)
            )
        )

        XCTAssertTrue(
            DailyPlanGenerator.missingTemplates(
                for: day,
                templates: [template],
                existingTasks: []
            ).isEmpty
        )
    }

    func testExistingTaskFromSameTemplateAndDayPreventsDuplicate() {
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let template = makeTemplate(
            recurrence: RecurrenceRule(kind: .daily, start: day)
        )
        let existingTask = DailyTaskSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            day: day,
            template: template
        )

        XCTAssertTrue(
            DailyPlanGenerator.missingTemplates(
                for: day,
                templates: [template],
                existingTasks: [existingTask]
            ).isEmpty
        )
    }

    func testDuplicateTemplateInputIsReturnedOnlyOnce() {
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let template = makeTemplate(
            recurrence: RecurrenceRule(kind: .daily, start: day)
        )

        let missing = DailyPlanGenerator.missingTemplates(
            for: day,
            templates: [template, template],
            existingTasks: []
        )

        XCTAssertEqual(missing.map(\.id), [template.id])
    }

    private func makeTemplate(recurrence: RecurrenceRule) -> TaskTemplateSnapshot {
        TaskTemplateSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "阅读",
            growthArea: .reading,
            requirement: .required,
            recurrence: recurrence
        )
    }
}
