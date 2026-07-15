import Foundation

public enum CSVExporter {
    public static func taskRecords(_ tasks: [DailyTaskSnapshot]) -> String {
        let header = [
            "task_id",
            "profile_id",
            "day",
            "title",
            "growth_area",
            "tags",
            "requirement",
            "source",
            "template_id",
            "status",
            "target_amount",
            "target_unit",
            "actual_quantity",
            "completed_at",
            "skip_reason",
            "corrected_at"
        ]

        let rows = tasks.sorted(by: taskOrder).map { task in
            [
                task.id.uuidString.lowercased(),
                task.profileID.uuidString.lowercased(),
                task.day.key,
                task.title,
                task.growthArea.rawValue,
                task.tags.joined(separator: "|"),
                task.requirement.rawValue,
                task.source.rawValue,
                task.templateID?.uuidString.lowercased() ?? "",
                task.state.rawValue,
                decimal(task.target?.amount),
                task.target?.unit ?? "",
                decimal(task.actualQuantity),
                task.completedAt.map(StableISO8601.string(from:)) ?? "",
                task.skipReason ?? "",
                task.correctedAt.map(StableISO8601.string(from:)) ?? ""
            ].map(CSVFieldEncoder.escaped).joined(separator: ",")
        }

        return ([header.joined(separator: ",")] + rows)
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func taskOrder(_ lhs: DailyTaskSnapshot, _ rhs: DailyTaskSnapshot) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func decimal(_ value: Decimal?) -> String {
        value.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }

}

public enum CSVFieldEncoder {
    public static func escaped(_ field: String) -> String {
        let safeField: String
        if let first = field.first, "=+-@\t\r".contains(first) {
            safeField = "'" + field
        } else {
            safeField = field
        }

        guard safeField.contains(where: { ",\"\r\n".contains($0) }) else {
            return safeField
        }
        return "\"" + safeField.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
