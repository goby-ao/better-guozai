import XCTest
@testable import GuozaiCore

final class CompletionPraiseCopyTests: XCTestCase {
    func testDayAchievementFocusesOnProcessAndGardenGrowth() {
        let praise = CompletionPraiseCopy.make(for: makeTask(), isDayAchieved: true)

        XCTAssertEqual(praise.title, "今天的计划完成了")
        XCTAssertEqual(praise.message, "你一项一项完成了今天的计划，小树也长大了一步。")
    }

    func testChildChallengeAcknowledgesAutonomousChoice() {
        let praise = CompletionPraiseCopy.make(
            for: makeTask(source: .challenge),
            isDayAchieved: false
        )

        XCTAssertEqual(praise.title, "自己选的挑战，做到了")
        XCTAssertEqual(praise.message, "这是你自己选的目标，你认真把它完成了。")
    }

    func testReadingPraiseIncludesCompletedQuantity() {
        let praise = CompletionPraiseCopy.make(
            for: makeTask(
                growthArea: .reading,
                target: QuantityTarget(amount: 30, unit: "分钟"),
                actualQuantity: 30
            ),
            isDayAchieved: false
        )

        XCTAssertEqual(praise.title, "专心阅读，做到了")
        XCTAssertEqual(praise.message, "你专心读完了 30 分钟，耐心又长大了一点。")
    }

    func testFamilyPraiseDescribesContributionInsteadOfAbility() {
        let praise = CompletionPraiseCopy.make(
            for: makeTask(growthArea: .familyResponsibility),
            isDayAchieved: false
        )

        XCTAssertEqual(praise.message, "你主动为家里出了一份力，这份行动很温暖。")
    }

    private func makeTask(
        growthArea: GrowthArea = .learning,
        source: DailyTaskSource = .template,
        target: QuantityTarget? = nil,
        actualQuantity: Decimal? = nil
    ) -> DailyTaskSnapshot {
        DailyTaskSnapshot(
            id: UUID(),
            profileID: UUID(),
            day: LocalDay(year: 2026, month: 7, day: 15),
            title: "测试任务",
            growthArea: growthArea,
            requirement: .required,
            source: source,
            target: target,
            state: .completed,
            actualQuantity: actualQuantity
        )
    }
}
