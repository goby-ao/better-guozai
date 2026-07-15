import XCTest
@testable import GuozaiCore

final class BadgeEvaluatorTests: XCTestCase {
    private let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testFirstCompletedTaskEarnsFirstCheckIn() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 14),
            requirement: .optional,
            state: .completed
        )

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [task],
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.firstCheckIn))
    }

    func testCompletedRequiredPlanEarnsFirstAchieved() {
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let tasks = [
            makeTask(day: day, requirement: .required, state: .completed, idSuffix: 1),
            makeTask(day: day, requirement: .required, state: .completed, idSuffix: 2)
        ]

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: tasks,
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.firstAchieved))
    }

    func testFiveAchievedDaysWithinSevenEarnsFlexibleGoal() {
        let achievedDayNumbers = [1, 2, 4, 6, 7]
        let tasks = achievedDayNumbers.enumerated().map { offset, dayNumber in
            makeTask(
                day: LocalDay(year: 2026, month: 7, day: dayNumber),
                requirement: .required,
                state: .completed,
                idSuffix: offset + 1
            )
        }

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: tasks,
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.flexFiveOfSeven))
    }

    func testFiveAchievedDaysSpreadBeyondSevenDoNotEarnFlexibleGoal() {
        let achievedDayNumbers = [1, 2, 3, 4, 8]
        let tasks = achievedDayNumbers.enumerated().map { offset, dayNumber in
            makeTask(
                day: LocalDay(year: 2026, month: 7, day: dayNumber),
                requirement: .required,
                state: .completed,
                idSuffix: offset + 1
            )
        }

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: tasks,
            alreadyAwarded: []
        )

        XCTAssertFalse(pending.contains(.flexFiveOfSeven))
    }

    func testAchievingAgainAfterInterruptedDayEarnsComeback() {
        let tasks = [
            makeTask(
                day: LocalDay(year: 2026, month: 7, day: 1),
                requirement: .required,
                state: .completed,
                idSuffix: 1
            ),
            makeTask(
                day: LocalDay(year: 2026, month: 7, day: 2),
                requirement: .required,
                state: .skipped,
                idSuffix: 2
            ),
            makeTask(
                day: LocalDay(year: 2026, month: 7, day: 3),
                requirement: .required,
                state: .completed,
                idSuffix: 3
            )
        ]

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: tasks,
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.comeback))
    }

    func testCompletedPersonalChallengeEarnsAutonomousChallenge() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 14),
            requirement: .optional,
            state: .completed,
            source: .challenge
        )

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [task],
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.autonomousChallenge))
    }

    func testCreatingFirstPersonalChallengeEarnsFirstChallenge() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 14),
            requirement: .optional,
            state: .pending,
            source: .challenge
        )

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [task],
            alreadyAwarded: []
        )

        XCTAssertTrue(pending.contains(.firstChallenge))
        XCTAssertFalse(pending.contains(.autonomousChallenge))
    }

    func testAlreadyAwardedBadgeIsNotReturnedAgain() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 14),
            requirement: .optional,
            state: .completed
        )

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [task],
            alreadyAwarded: [.firstCheckIn]
        )

        XCTAssertFalse(pending.contains(.firstCheckIn))
    }

    func testSkippedTaskDoesNotEarnFirstCheckIn() {
        let task = makeTask(
            day: LocalDay(year: 2026, month: 7, day: 14),
            requirement: .required,
            state: .skipped
        )

        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [task],
            alreadyAwarded: []
        )

        XCTAssertFalse(pending.contains(.firstCheckIn))
        XCTAssertFalse(pending.contains(.firstAchieved))
    }

    func testHistoricalChangesProduceNoRevocationCommands() {
        let pending = BadgeEvaluator.pendingAwards(
            for: profileID,
            tasks: [],
            alreadyAwarded: [.flexFiveOfSeven]
        )

        XCTAssertTrue(pending.isEmpty)
    }

    private func makeTask(
        day: LocalDay,
        requirement: TaskRequirement,
        state: DailyTaskState,
        source: DailyTaskSource = .parentOneOff,
        idSuffix: Int = 1
    ) -> DailyTaskSnapshot {
        DailyTaskSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", idSuffix))!,
            profileID: profileID,
            day: day,
            title: "任务 \(idSuffix)",
            growthArea: .learning,
            requirement: requirement,
            source: source,
            state: state
        )
    }
}
