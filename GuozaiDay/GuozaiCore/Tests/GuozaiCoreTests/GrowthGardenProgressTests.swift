import Foundation
import XCTest
@testable import GuozaiCore

final class GrowthGardenProgressTests: XCTestCase {
    func testGrowthStagesFollowNineAchievedDayMilestones() {
        let expectations: [(ClosedRange<Int>, GrowthGardenStage)] = [
            (0...0, .seed),
            (1...2, .crackedSeed),
            (3...5, .sprout),
            (6...9, .seedling),
            (10...13, .strongSeedling),
            (14...17, .youngTree),
            (18...22, .leafyTree),
            (23...27, .flourishing),
            (28...28, .fruiting)
        ]

        for (days, expectedStage) in expectations {
            for day in days {
                XCTAssertEqual(
                    GrowthGardenProgress(achievedDayCount: day).stage,
                    expectedStage,
                    "第 \(day) 天的成长阶段错误"
                )
            }
        }
    }

    func testDaysUntilNextStageUseNineStageMilestones() {
        let expectations = [
            (day: 0, remaining: 1),
            (day: 1, remaining: 2),
            (day: 3, remaining: 3),
            (day: 6, remaining: 4),
            (day: 10, remaining: 4),
            (day: 14, remaining: 4),
            (day: 18, remaining: 5),
            (day: 23, remaining: 5),
            (day: 28, remaining: 0)
        ]

        for expectation in expectations {
            XCTAssertEqual(
                GrowthGardenProgress(achievedDayCount: expectation.day).daysUntilNextStage,
                expectation.remaining
            )
        }
    }

    func testExistingStageRawValuesRemainBackwardCompatible() {
        XCTAssertEqual(GrowthGardenStage.seed.rawValue, 0)
        XCTAssertEqual(GrowthGardenStage.sprout.rawValue, 1)
        XCTAssertEqual(GrowthGardenStage.seedling.rawValue, 2)
        XCTAssertEqual(GrowthGardenStage.youngTree.rawValue, 3)
        XCTAssertEqual(GrowthGardenStage.leafyTree.rawValue, 4)
        XCTAssertEqual(GrowthGardenStage.flourishing.rawValue, 5)
    }

    func testGrowthStageOrderFollowsTheNineStageJourney() {
        XCTAssertEqual(
            GrowthGardenStage.journeyOrder,
            [
                .seed,
                .crackedSeed,
                .sprout,
                .seedling,
                .strongSeedling,
                .youngTree,
                .leafyTree,
                .flourishing,
                .fruiting
            ]
        )
    }

    func testExistingStageCodableValuesRemainBackwardCompatible() throws {
        let expectedStages: [GrowthGardenStage] = [
            .seed,
            .sprout,
            .seedling,
            .youngTree,
            .leafyTree,
            .flourishing
        ]

        for (rawValue, expectedStage) in expectedStages.enumerated() {
            let data = Data(String(rawValue).utf8)
            let decodedStage = try JSONDecoder().decode(GrowthGardenStage.self, from: data)
            XCTAssertEqual(decodedStage, expectedStage)
        }
    }

    func testTwentyEightAchievedDaysShowTheCompletedTree() {
        let progress = GrowthGardenProgress(achievedDayCount: 28)

        XCTAssertEqual(progress.completedTreeCount, 1)
        XCTAssertEqual(progress.currentTreeDay, 28)
        XCTAssertEqual(progress.stage, .fruiting)
        XCTAssertEqual(progress.daysUntilNextStage, 0)
        XCTAssertEqual(progress.currentTreeNumber, 1)
    }

    func testTheDayAfterACompletedTreeStartsTheNextSprout() {
        let progress = GrowthGardenProgress(achievedDayCount: 29)

        XCTAssertEqual(progress.completedTreeCount, 1)
        XCTAssertEqual(progress.currentTreeDay, 1)
        XCTAssertEqual(progress.stage, .crackedSeed)
        XCTAssertEqual(progress.currentTreeNumber, 2)
    }

    func testGrowthContinuesAcrossMultipleTrees() {
        let progress = GrowthGardenProgress(achievedDayCount: 63)

        XCTAssertEqual(progress.completedTreeCount, 2)
        XCTAssertEqual(progress.currentTreeDay, 7)
        XCTAssertEqual(progress.stage, .seedling)
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
