import SwiftData
import XCTest
@testable import GuozaiCore
@testable import GuozaiData

final class WishRewardSelectionTests: XCTestCase {
    @MainActor
    func testSelectingWishClearsPreviousWeeklySelectionAndUsesFiveOfSeven() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let first = WishRewardRecord(profileId: profile.id, title: "去骑车", weeklyTarget: 3)
        let second = WishRewardRecord(profileId: profile.id, title: "看一场电影", weeklyTarget: 7)
        context.insert(profile)
        context.insert(first)
        context.insert(second)
        try PersistenceWriter.save(context)

        try WishRewardStore.select(first, selectedAt: Date(timeIntervalSince1970: 10), in: context)
        try WishRewardStore.select(second, selectedAt: Date(timeIntervalSince1970: 20), in: context)

        XCTAssertNil(first.selectedAt)
        XCTAssertEqual(second.selectedAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(second.weeklyTarget, 5)
    }

    @MainActor
    func testOnlySelectedWeeklyWishUnlocksWhileBadgeWishKeepsOriginalRule() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let selected = WishRewardRecord(
            profileId: profile.id,
            title: "周末去公园",
            weeklyTarget: 5,
            selectedAt: Date(timeIntervalSince1970: 10)
        )
        let unselected = WishRewardRecord(
            profileId: profile.id,
            title: "买一本新书",
            weeklyTarget: 5
        )
        let badgeLinked = WishRewardRecord(
            profileId: profile.id,
            title: "一起做蛋糕",
            linkedBadgeId: BadgeCode.firstCheckIn.rawValue
        )
        context.insert(profile)
        context.insert(selected)
        context.insert(unselected)
        context.insert(badgeLinked)

        for dayNumber in 13...17 {
            insertAchievedDay(
                LocalDay(year: 2026, month: 7, day: dayNumber),
                profileID: profile.id,
                into: context
            )
        }
        try PersistenceWriter.save(context)

        _ = try AchievementStore.evaluate(
            profileId: profile.id,
            today: LocalDay(year: 2026, month: 7, day: 17),
            in: context
        )

        XCTAssertEqual(selected.state, .unlocked)
        XCTAssertEqual(unselected.state, .locked)
        XCTAssertEqual(badgeLinked.state, .unlocked)
    }

    @MainActor
    func testSecondWeeklyWishCannotReuseTheSameWeeksProgress() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let first = WishRewardRecord(
            profileId: profile.id,
            title: "周末去公园",
            weeklyTarget: 5,
            state: .unlocked,
            unlockedAt: LocalDay(year: 2026, month: 7, day: 15).date()
        )
        let second = WishRewardRecord(
            profileId: profile.id,
            title: "买一本新书",
            weeklyTarget: 5,
            selectedAt: LocalDay(year: 2026, month: 7, day: 16).date()
        )
        context.insert(profile)
        context.insert(first)
        context.insert(second)

        for dayNumber in 13...17 {
            insertAchievedDay(
                LocalDay(year: 2026, month: 7, day: dayNumber),
                profileID: profile.id,
                into: context
            )
        }
        try PersistenceWriter.save(context)

        _ = try AchievementStore.evaluate(
            profileId: profile.id,
            today: LocalDay(year: 2026, month: 7, day: 17),
            in: context
        )

        XCTAssertEqual(second.state, .locked)
        XCTAssertNil(second.selectedAt)
    }

    @MainActor
    func testPreviousWeeksUnlockDoesNotBlockANewSelection() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let previous = WishRewardRecord(
            profileId: profile.id,
            title: "一起做蛋糕",
            weeklyTarget: 5,
            state: .claimed,
            unlockedAt: LocalDay(year: 2026, month: 7, day: 19).date()
        )
        let next = WishRewardRecord(
            profileId: profile.id,
            title: "周末去骑车",
            weeklyTarget: 5
        )
        context.insert(profile)
        context.insert(previous)
        context.insert(next)
        try PersistenceWriter.save(context)

        let selectedAt = try XCTUnwrap(LocalDay(year: 2026, month: 7, day: 20).date())
        try WishRewardStore.select(next, selectedAt: selectedAt, in: context)

        XCTAssertEqual(next.selectedAt, selectedAt)
    }

    @MainActor
    func testSelectionIsRejectedAfterAWeeklyWishUnlocksThisWeek() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let unlocked = WishRewardRecord(
            profileId: profile.id,
            title: "周末去公园",
            weeklyTarget: 5,
            state: .unlocked,
            unlockedAt: LocalDay(year: 2026, month: 7, day: 15).date()
        )
        let next = WishRewardRecord(
            profileId: profile.id,
            title: "买一本新书",
            weeklyTarget: 5
        )
        context.insert(profile)
        context.insert(unlocked)
        context.insert(next)
        try PersistenceWriter.save(context)

        let selectedAt = try XCTUnwrap(LocalDay(year: 2026, month: 7, day: 16).date())
        XCTAssertThrowsError(try WishRewardStore.select(next, selectedAt: selectedAt, in: context)) { error in
            XCTAssertEqual(error as? WishRewardStoreError, .weeklyWishAlreadyUnlocked)
        }
        XCTAssertNil(next.selectedAt)
    }

    @MainActor
    func testMondayThroughFridayProgressStillUnlocksOnSunday() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let wish = WishRewardRecord(
            profileId: profile.id,
            title: "周末一起看电影",
            weeklyTarget: 5,
            selectedAt: LocalDay(year: 2026, month: 7, day: 13).date()
        )
        context.insert(profile)
        context.insert(wish)
        for dayNumber in 13...17 {
            insertAchievedDay(
                LocalDay(year: 2026, month: 7, day: dayNumber),
                profileID: profile.id,
                into: context
            )
        }
        try PersistenceWriter.save(context)

        _ = try AchievementStore.evaluate(
            profileId: profile.id,
            today: LocalDay(year: 2026, month: 7, day: 19),
            in: context
        )

        XCTAssertEqual(wish.state, .unlocked)
    }

    @MainActor
    func testUnfinishedWishCarriesIntoTheNextWeek() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let selectedAt = try XCTUnwrap(LocalDay(year: 2026, month: 7, day: 19).date())
        let wish = WishRewardRecord(
            profileId: profile.id,
            title: "周末去骑车",
            weeklyTarget: 5,
            selectedAt: selectedAt
        )
        context.insert(profile)
        context.insert(wish)
        try PersistenceWriter.save(context)

        _ = try AchievementStore.evaluate(
            profileId: profile.id,
            today: LocalDay(year: 2026, month: 7, day: 20),
            in: context
        )

        XCTAssertEqual(wish.state, .locked)
        XCTAssertEqual(wish.selectedAt, selectedAt)
    }

    @MainActor
    func testUnlockedWishDoesNotRelockAfterHistoricalCorrection() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profile = ProfileRecord(nickname: "果仔")
        let wish = WishRewardRecord(
            profileId: profile.id,
            title: "周末去公园",
            weeklyTarget: 5,
            selectedAt: LocalDay(year: 2026, month: 7, day: 13).date()
        )
        context.insert(profile)
        context.insert(wish)
        for dayNumber in 13...17 {
            insertAchievedDay(
                LocalDay(year: 2026, month: 7, day: dayNumber),
                profileID: profile.id,
                into: context
            )
        }
        try PersistenceWriter.save(context)

        let today = LocalDay(year: 2026, month: 7, day: 17)
        _ = try AchievementStore.evaluate(profileId: profile.id, today: today, in: context)
        let unlockedAt = try XCTUnwrap(wish.unlockedAt)

        let completedTask = try XCTUnwrap(
            context.fetch(FetchDescriptor<DailyTaskRecord>()).first { $0.status == .completed }
        )
        completedTask.status = .pending
        completedTask.completedAt = nil
        try PersistenceWriter.save(context)
        _ = try AchievementStore.evaluate(profileId: profile.id, today: today, in: context)

        XCTAssertEqual(wish.state, .unlocked)
        XCTAssertEqual(wish.unlockedAt, unlockedAt)
    }

    @MainActor
    private func insertAchievedDay(
        _ day: LocalDay,
        profileID: UUID,
        into context: ModelContext
    ) {
        let plan = DailyPlanRecord(profileId: profileID, dayKey: day.key)
        context.insert(plan)
        context.insert(DailyTaskRecord(
            planId: plan.id,
            profileId: profileID,
            dayKey: day.key,
            title: "今日必做",
            growthDomain: .learning,
            status: .completed,
            completedAt: day.date(calendar: .guozaiGregorian)
        ))
    }
}
