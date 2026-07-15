import XCTest
@testable import GuozaiCore

final class DailyProgressTests: XCTestCase {
    func testAchievedWhenEveryRequiredTaskIsCompleted() {
        let tasks = [
            makeTask(requirement: .required, state: .completed, idSuffix: 1),
            makeTask(requirement: .required, state: .completed, idSuffix: 2),
            makeTask(requirement: .optional, state: .pending, idSuffix: 3)
        ]

        let progress = DailyProgress(tasks: tasks)

        XCTAssertTrue(progress.isAchieved)
        XCTAssertEqual(progress.requiredCount, 2)
        XCTAssertEqual(progress.completedRequiredCount, 2)
    }

    func testSkippedRequiredTaskDoesNotCountAsCompleted() {
        let progress = DailyProgress(tasks: [
            makeTask(requirement: .required, state: .completed, idSuffix: 1),
            makeTask(requirement: .required, state: .skipped, idSuffix: 2)
        ])

        XCTAssertFalse(progress.isAchieved)
        XCTAssertEqual(progress.completedRequiredCount, 1)
        XCTAssertEqual(progress.skippedCount, 1)
    }

    func testPlanWithoutRequiredTasksDoesNotAutoAchieve() {
        let progress = DailyProgress(tasks: [
            makeTask(requirement: .optional, state: .completed, idSuffix: 1)
        ])

        XCTAssertFalse(progress.isAchieved)
        XCTAssertEqual(progress.requiredCount, 0)
    }

    private func makeTask(
        requirement: TaskRequirement,
        state: DailyTaskState,
        idSuffix: Int
    ) -> DailyTaskSnapshot {
        DailyTaskSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", idSuffix))!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            day: LocalDay(year: 2026, month: 7, day: 14),
            title: "任务 \(idSuffix)",
            growthArea: .learning,
            requirement: requirement,
            source: .parentOneOff,
            state: state
        )
    }
}
