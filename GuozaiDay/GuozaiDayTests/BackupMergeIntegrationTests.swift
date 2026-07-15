import SwiftData
import XCTest
@testable import GuozaiCore
@testable import GuozaiData

final class BackupMergeIntegrationTests: XCTestCase {
    @MainActor
    func testFreshSeedIsReplacedBySingleProfileBackupWithoutDuplicateTemplates() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let today = LocalDay(year: 2026, month: 7, day: 14)
        let seededProfile = try SeedService.ensureSeeded(in: context, today: today)
        try DailyPlanStore.ensurePlan(for: today, profile: seededProfile, in: context)
        _ = try DailyPlanStore.ensureReflection(for: today, profile: seededProfile, in: context)

        let importedProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000009001")!
        let importedTemplateID = UUID(uuidString: "00000000-0000-0000-0000-000000009002")!
        let importedTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000009003")!
        let exportedAt = Date(timeIntervalSince1970: 1_752_470_400)
        let payload = BackupPayload(
            exportedAt: exportedAt,
            appVersion: "1.0",
            profiles: [
                ProfileSnapshot(
                    id: importedProfileID,
                    nickname: "果仔旧档案",
                    avatarSymbol: "star.fill",
                    currentGrade: "四年级"
                )
            ],
            templates: [
                TaskTemplateSnapshot(
                    id: importedTemplateID,
                    profileID: importedProfileID,
                    title: "旧设备阅读计划",
                    growthArea: .reading,
                    requirement: .required,
                    recurrence: RecurrenceRule(kind: .daily, start: today)
                )
            ],
            tasks: [
                DailyTaskSnapshot(
                    id: importedTaskID,
                    profileID: importedProfileID,
                    day: today,
                    title: "旧设备阅读计划",
                    growthArea: .reading,
                    requirement: .required,
                    source: .template,
                    templateID: importedTemplateID,
                    state: .completed,
                    completedAt: exportedAt
                )
            ]
        )

        let result = try AppBackupService.merge(payload, into: context)
        let profiles = try context.fetch(FetchDescriptor<ProfileRecord>())
        let templates = try context.fetch(FetchDescriptor<TaskTemplateRecord>())
        let tasks = try context.fetch(FetchDescriptor<DailyTaskRecord>())

        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.id, seededProfile.id)
        XCTAssertEqual(profiles.first?.nickname, "果仔旧档案")
        XCTAssertEqual(profiles.first?.grade, "四年级")
        XCTAssertEqual(templates.map(\.title), ["旧设备阅读计划"])
        XCTAssertEqual(tasks.map(\.id), [importedTaskID])
        XCTAssertTrue(tasks.allSatisfy { $0.profileId == seededProfile.id })
        XCTAssertEqual(result.insertedTemplates, 1)
        XCTAssertEqual(result.insertedTasks, 1)
        XCTAssertEqual(result.skippedProfiles, 1)
    }

    @MainActor
    func testImportRejectsRecordsOwnedByAnotherProfile() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000009101")!
        let otherProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000009102")!
        let payload = BackupPayload(
            exportedAt: .now,
            appVersion: "1.0",
            profiles: [ProfileSnapshot(id: profileID, nickname: "果仔")],
            tags: [TagSnapshot(id: UUID(), profileID: otherProfileID, name: "异常")]
        )

        XCTAssertThrowsError(try AppBackupService.candidate(from: BackupCodec.encode(payload)))
    }

    @MainActor
    func testSystemBadgesDeduplicateByStableIdentityAcrossBackups() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000009201")!
        let awardedAt = Date(timeIntervalSince1970: 1_752_470_400)

        func payload(badgeID: UUID) -> BackupPayload {
            BackupPayload(
                exportedAt: awardedAt,
                appVersion: "1.0",
                profiles: [ProfileSnapshot(id: profileID, nickname: "果仔")],
                badgeAwards: [
                    BadgeAwardSnapshot(
                        id: badgeID,
                        profileID: profileID,
                        badgeCode: BadgeCode.firstCheckIn.rawValue,
                        name: "第一颗星",
                        source: .system,
                        awardedAt: awardedAt
                    )
                ]
            )
        }

        _ = try AppBackupService.merge(payload(badgeID: UUID()), into: context)
        let second = try AppBackupService.merge(payload(badgeID: UUID()), into: context)
        let badges = try context.fetch(FetchDescriptor<BadgeAwardRecord>())

        XCTAssertEqual(badges.count, 1)
        XCTAssertEqual(second.skippedBadges, 1)
    }

    @MainActor
    func testSelectedWishSurvivesExportAndMerge() throws {
        let sourceContainer = try PersistenceModels.makeContainer(inMemory: true)
        let sourceContext = ModelContext(sourceContainer)
        let profile = ProfileRecord(nickname: "果仔")
        let selectedAt = Date(timeIntervalSince1970: 1_752_556_800)
        let reward = WishRewardRecord(
            profileId: profile.id,
            title: "周末一起骑车",
            weeklyTarget: 5,
            selectedAt: selectedAt
        )
        sourceContext.insert(profile)
        sourceContext.insert(reward)
        try PersistenceWriter.save(sourceContext)

        let payload = try AppBackupService.makePayload(in: sourceContext, exportedAt: selectedAt)
        XCTAssertEqual(payload.wishRewards.first?.selectedAt, selectedAt)

        let destinationContainer = try PersistenceModels.makeContainer(inMemory: true)
        let destinationContext = ModelContext(destinationContainer)
        _ = try AppBackupService.merge(payload, into: destinationContext)
        let imported = try XCTUnwrap(destinationContext.fetch(FetchDescriptor<WishRewardRecord>()).first)

        XCTAssertEqual(imported.selectedAt, selectedAt)
    }

    @MainActor
    func testMergeKeepsOnlyTheMostRecentlySelectedWeeklyWish() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let localProfile = ProfileRecord(nickname: "果仔")
        let localWish = WishRewardRecord(
            profileId: localProfile.id,
            title: "去骑车",
            weeklyTarget: 5,
            selectedAt: Date(timeIntervalSince1970: 10)
        )
        context.insert(localProfile)
        context.insert(localWish)
        try PersistenceWriter.save(context)

        let importedProfileID = UUID()
        let importedWishID = UUID()
        let payload = BackupPayload(
            exportedAt: Date(timeIntervalSince1970: 30),
            appVersion: "1.0",
            profiles: [ProfileSnapshot(id: importedProfileID, nickname: "果仔")],
            wishRewards: [
                WishRewardSnapshot(
                    id: importedWishID,
                    profileID: importedProfileID,
                    name: "看一场电影",
                    weeklyTarget: 5,
                    selectedAt: Date(timeIntervalSince1970: 20)
                )
            ]
        )

        _ = try AppBackupService.merge(payload, into: context)
        let secondMerge = try AppBackupService.merge(payload, into: context)
        let rewards = try context.fetch(FetchDescriptor<WishRewardRecord>())
        let selected = rewards.filter { $0.selectedAt != nil }

        XCTAssertEqual(selected.map(\.id), [importedWishID])
        XCTAssertEqual(secondMerge.skippedRewards, 1)
    }
}
