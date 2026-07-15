import XCTest
@testable import GuozaiCore

final class BackupCodecTests: XCTestCase {
    func testVersionedPayloadRoundTripsAsStableJSON() throws {
        let payload = BackupPayload(
            exportedAt: Date(timeIntervalSince1970: 0),
            appVersion: "1.0.0"
        )

        let data = try BackupCodec.encode(payload)
        let decoded = try BackupCodec.decode(data)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(decoded, payload)
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"))
        XCTAssertTrue(json.contains("1970-01-01T00:00:00.000Z"))
    }

    func testAllGrowthRecordsSurviveBackupRoundTrip() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let templateID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let day = LocalDay(year: 2026, month: 7, day: 14)
        let moment = Date(timeIntervalSince1970: 1_752_470_400.125)
        let template = TaskTemplateSnapshot(
            id: templateID,
            profileID: profileID,
            title: "阅读",
            growthArea: .reading,
            tags: ["课外书"],
            requirement: .required,
            recurrence: RecurrenceRule(kind: .daily, start: day),
            target: QuantityTarget(amount: 30, unit: "分钟"),
            sortOrder: 2,
            isActive: true,
            reminderHour: 18,
            reminderMinute: 30,
            createdAt: moment,
            updatedAt: moment
        )
        let task = DailyTaskSnapshot(
            id: taskID,
            profileID: profileID,
            day: day,
            title: "阅读",
            growthArea: .reading,
            tags: ["课外书"],
            requirement: .required,
            source: .template,
            templateID: templateID,
            target: QuantityTarget(amount: 30, unit: "分钟"),
            state: .completed,
            actualQuantity: 35,
            completedAt: moment,
            sortOrder: 2,
            createdAt: moment,
            updatedAt: moment
        )
        let payload = BackupPayload(
            exportedAt: moment,
            appVersion: "1.0.0",
            profiles: [
                ProfileSnapshot(
                    id: profileID,
                    nickname: "果仔",
                    avatarSymbol: "face.smiling.fill",
                    currentGrade: "四年级"
                )
            ],
            tags: [
                TagSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    profileID: profileID,
                    name: "课外书",
                    createdAt: moment
                )
            ],
            templates: [template],
            dailyPlans: [
                DailyPlanSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    profileID: profileID,
                    day: day,
                    generatedAt: moment,
                    lastModifiedAt: moment
                )
            ],
            tasks: [task],
            reflections: [
                DailyReflectionSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                    profileID: profileID,
                    day: day,
                    mood: "开心",
                    selfRating: 5,
                    proudMoment: "主动完成阅读",
                    parentEncouragement: "保持好奇",
                    createdAt: moment,
                    updatedAt: moment
                )
            ],
            badgeAwards: [
                BadgeAwardSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                    profileID: profileID,
                    badgeCode: BadgeCode.firstCheckIn.rawValue,
                    name: "第一次打卡",
                    source: .system,
                    awardedAt: moment,
                    ruleVersion: 1,
                    evidenceRecordIDs: [taskID],
                    symbol: "sparkle"
                )
            ],
            wishRewards: [
                WishRewardSnapshot(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                    profileID: profileID,
                    name: "去公园",
                    linkedBadgeCode: BadgeCode.flexFiveOfSeven.rawValue,
                    weeklyTarget: 5,
                    selectedAt: moment,
                    unlockedAt: moment,
                    createdAt: moment
                )
            ]
        )

        let decoded = try BackupCodec.decode(BackupCodec.encode(payload))

        XCTAssertEqual(decoded, payload)
    }

    func testLegacyVersionOneWishWithoutSelectionStillDecodes() throws {
        let profileID = UUID()
        let payload = BackupPayload(
            exportedAt: Date(timeIntervalSince1970: 0),
            appVersion: "1.0.0",
            profiles: [ProfileSnapshot(id: profileID, nickname: "果仔")],
            wishRewards: [
                WishRewardSnapshot(
                    id: UUID(),
                    profileID: profileID,
                    name: "周末去骑车",
                    weeklyTarget: 5,
                    selectedAt: Date(timeIntervalSince1970: 10)
                )
            ]
        )
        let encoded = try BackupCodec.encode(payload)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var rewards = try XCTUnwrap(object["wishRewards"] as? [[String: Any]])
        rewards[0].removeValue(forKey: "selectedAt")
        object["wishRewards"] = rewards

        let decoded = try BackupCodec.decode(JSONSerialization.data(withJSONObject: object))

        XCTAssertNil(decoded.wishRewards.first?.selectedAt)
    }

    func testUnsupportedBackupVersionIsRejected() throws {
        let validData = try BackupCodec.encode(
            BackupPayload(exportedAt: Date(timeIntervalSince1970: 0), appVersion: "1.0.0")
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: validData) as? [String: Any]
        )
        object["schemaVersion"] = 99
        let unsupportedData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try BackupCodec.decode(unsupportedData)) { error in
            XCTAssertEqual(error as? BackupCodecError, .unsupportedSchemaVersion(99))
        }
    }

    func testUnsupportedVersionIsReportedBeforeFutureFieldsAreDecoded() {
        let futureEnvelope = Data(#"{"schemaVersion":99}"#.utf8)

        XCTAssertThrowsError(try BackupCodec.decode(futureEnvelope)) { error in
            XCTAssertEqual(error as? BackupCodecError, .unsupportedSchemaVersion(99))
        }
    }
}
