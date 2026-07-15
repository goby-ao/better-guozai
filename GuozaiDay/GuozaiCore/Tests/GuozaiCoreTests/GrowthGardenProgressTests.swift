import XCTest
@testable import GuozaiCore

final class GrowthGardenProgressTests: XCTestCase {
    func testGrowthStagesFollowAchievedDayMilestones() {
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 0).stage, .seed)
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 1).stage, .sprout)
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 3).stage, .seedling)
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 7).stage, .youngTree)
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 14).stage, .leafyTree)
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: 21).stage, .flourishing)
    }

    func testTwentyEightAchievedDaysShowTheCompletedTree() {
        let progress = GrowthGardenProgress(achievedDayCount: 28)

        XCTAssertEqual(progress.completedTreeCount, 1)
        XCTAssertEqual(progress.currentTreeDay, 28)
        XCTAssertEqual(progress.stage, .flourishing)
        XCTAssertEqual(progress.daysUntilNextStage, 0)
        XCTAssertEqual(progress.currentTreeNumber, 1)
    }

    func testTheDayAfterACompletedTreeStartsTheNextSprout() {
        let progress = GrowthGardenProgress(achievedDayCount: 29)

        XCTAssertEqual(progress.completedTreeCount, 1)
        XCTAssertEqual(progress.currentTreeDay, 1)
        XCTAssertEqual(progress.stage, .sprout)
        XCTAssertEqual(progress.currentTreeNumber, 2)
    }

    func testGrowthContinuesAcrossMultipleTrees() {
        let progress = GrowthGardenProgress(achievedDayCount: 63)

        XCTAssertEqual(progress.completedTreeCount, 2)
        XCTAssertEqual(progress.currentTreeDay, 7)
        XCTAssertEqual(progress.stage, .youngTree)
        XCTAssertEqual(progress.currentTreeNumber, 3)
    }

    func testNegativeInputIsClampedToEmptyGarden() {
        XCTAssertEqual(GrowthGardenProgress(achievedDayCount: -4).achievedDayCount, 0)
    }

    func testTasksOnTheSameDayOnlyGrowOneStep() {
        let day = LocalDay(year: 2026, month: 7, day: 15)
        let tasks = [
            makeTask(day: day, requirement: .required, state: .completed),
            makeTask(day: day, requirement: .required, state: .completed)
        ]

        XCTAssertEqual(GrowthGardenProgress(tasks: tasks).achievedDayCount, 1)
    }

    func testOptionalCompletionAloneDoesNotGrowTheGarden() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 15),
            requirement: .optional,
            state: .completed
        )

        XCTAssertEqual(GrowthGardenProgress(tasks: [task]).achievedDayCount, 0)
    }

    private func makeTask(
        day: LocalDay,
        requirement: TaskRequirement,
        state: DailyTaskState
    ) -> DailyTaskSnapshot {
        DailyTaskSnapshot(
            id: UUID(),
            profileID: UUID(),
            day: day,
            title: "测试任务",
            growthArea: .learning,
            requirement: requirement,
            source: .template,
            state: state
        )
    }
}
