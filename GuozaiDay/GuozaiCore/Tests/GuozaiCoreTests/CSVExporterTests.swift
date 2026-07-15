import XCTest
@testable import GuozaiCore

final class CSVExporterTests: XCTestCase {
    func testTaskRecordsCSVContainsStableHeaderAndTaskFields() {
        let task = DailyTaskSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            day: LocalDay(year: 2026, month: 7, day: 14),
            title: "阅读经典",
            growthArea: .reading,
            tags: ["语文", "课外书"],
            requirement: .required,
            source: .template,
            templateID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            target: QuantityTarget(amount: 30, unit: "分钟"),
            state: .completed,
            actualQuantity: 35,
            completedAt: Date(timeIntervalSince1970: 0)
        )

        let csv = CSVExporter.taskRecords([task])

        XCTAssertTrue(csv.hasPrefix(
            "task_id,profile_id,day,title,growth_area,tags,requirement,source,template_id,status,target_amount,target_unit,actual_quantity,completed_at,skip_reason,corrected_at\r\n"
        ))
        XCTAssertTrue(csv.contains("2026-07-14,阅读经典,reading,语文|课外书,required,template"))
        XCTAssertTrue(csv.contains(",30,分钟,35,1970-01-01T00:00:00.000Z,,"))
    }

    func testTaskRecordsCSVEscapesCommaQuoteAndNewline() {
        let task = DailyTaskSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            day: LocalDay(year: 2026, month: 7, day: 14),
            title: "读, \"经典\"\n下一页",
            growthArea: .reading,
            requirement: .optional,
            source: .challenge
        )

        let csv = CSVExporter.taskRecords([task])

        XCTAssertTrue(csv.contains("\"读, \"\"经典\"\"\n下一页\""))
    }

    func testTaskRecordsCSVNeutralizesSpreadsheetFormulaPrefixes() {
        let task = DailyTaskSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            day: LocalDay(year: 2026, month: 7, day: 14),
            title: "=HYPERLINK(\"https://example.com\")",
            growthArea: .learning,
            requirement: .optional,
            source: .challenge
        )

        let csv = CSVExporter.taskRecords([task])

        XCTAssertTrue(csv.contains("'="))
        XCTAssertFalse(csv.contains(",=HYPERLINK"))
    }
}
