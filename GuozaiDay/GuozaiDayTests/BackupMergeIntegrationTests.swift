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
}
