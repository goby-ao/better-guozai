import SwiftData
import XCTest
@testable import GuozaiCore
@testable import GuozaiData

final class DailyReflectionMoodPersistenceTests: XCTestCase {
    @MainActor
    func testVeryUnhappyMoodPersistsAndSurvivesBackupRoundTrip() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let profileID = UUID()
        let reflection = DailyReflectionRecord(
            profileId: profileID,
            dayKey: "2026-07-14",
            mood: .veryUnhappy
        )
        context.insert(reflection)
        try context.save()

        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<DailyReflectionRecord>()).first)
        XCTAssertEqual(stored.mood, .veryUnhappy)
        XCTAssertEqual(stored.mood?.title, "很不开心")

        let payload = try AppBackupService.makePayload(in: context, appVersion: "1.0")
        let decoded = try BackupCodec.decode(BackupCodec.encode(payload))
        XCTAssertEqual(decoded.reflections.first?.mood, StoredMood.veryUnhappy.rawValue)
    }
}
