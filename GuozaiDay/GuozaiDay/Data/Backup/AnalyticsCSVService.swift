import Foundation
import SwiftData

enum AnalyticsCSVKind: String, CaseIterable, Identifiable {
    case tasks
    case dailySummary
    case quantities
    case badges

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: "任务明细"
        case .dailySummary: "每日汇总"
        case .quantities: "量化记录"
        case .badges: "勋章记录"
        }
    }

    var fileLabel: String {
        switch self {
        case .tasks: "任务明细"
        case .dailySummary: "每日汇总"
        case .quantities: "量化记录"
        case .badges: "勋章记录"
        }
    }

    var subtitle: String {
        switch self {
        case .tasks: "每项任务、状态、标签与实际完成量"
        case .dailySummary: "按天查看完成率、达成情况与自评"
        case .quantities: "专门分析阅读分钟、运动时长等指标"
        case .badges: "勋章获得时间、来源与授予理由"
        }
    }

    var symbol: String {
        switch self {
        case .tasks: "tablecells.fill"
        case .dailySummary: "chart.bar.doc.horizontal.fill"
        case .quantities: "ruler.fill"
        case .badges: "medal.fill"
        }
    }
}

@MainActor
enum AnalyticsCSVService {
    static func document(_ kind: AnalyticsCSVKind, in context: ModelContext) throws -> CSVExportDocument {
        let payload = try AppBackupService.makePayload(in: context)
        let content: String
        switch kind {
        case .tasks:
            content = CSVExporter.taskRecords(payload.tasks)
        case .dailySummary:
            content = dailySummary(tasks: payload.tasks, reflections: payload.reflections)
        case .quantities:
            content = quantities(payload.tasks)
        case .badges:
            content = badges(payload.badgeAwards)
        }
        return CSVExportDocument(content: content)
    }

    private static func dailySummary(
        tasks: [DailyTaskSnapshot],
        reflections: [DailyReflectionSnapshot]
    ) -> String {
        let header = [
            "day", "task_total", "completed", "skipped", "pending",
            "required_total", "required_completed", "day_achieved", "self_rating", "mood"
        ]
        let reflectionByDay = Dictionary(
            reflections.map { ($0.day.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let grouped: [LocalDay: [DailyTaskSnapshot]] = Dictionary(grouping: tasks, by: \.day)
        let sortedGroups = grouped.sorted { $0.key < $1.key }
        var rows: [[String]] = []
        rows.reserveCapacity(sortedGroups.count)
        for (day, records) in sortedGroups {
            let required = records.filter { $0.requirement == .required }
            let completed = records.count { $0.state == .completed }
            let skipped = records.count { $0.state == .skipped }
            let requiredCompleted = required.count { $0.state == .completed }
            let achieved = !required.isEmpty && requiredCompleted == required.count
            let reflection = reflectionByDay[day.key]
            rows.append([
                day.key,
                String(records.count),
                String(completed),
                String(skipped),
                String(records.count - completed - skipped),
                String(required.count),
                String(requiredCompleted),
                achieved ? "true" : "false",
                reflection?.selfRating.map(String.init) ?? "",
                reflection?.mood ?? ""
            ])
        }
        return csv(header: header, rows: rows)
    }

    private static func quantities(_ tasks: [DailyTaskSnapshot]) -> String {
        let header = [
            "day", "task_id", "title", "growth_area", "status",
            "target_amount", "actual_amount", "unit", "completion_ratio"
        ]
        let rows = tasks
            .filter { $0.target != nil || $0.actualQuantity != nil }
            .sorted { $0.day == $1.day ? $0.id.uuidString < $1.id.uuidString : $0.day < $1.day }
            .map { task -> [String] in
                let target = task.target?.amount
                let actual = task.actualQuantity
                let ratio: String
                if let target, target != 0, let actual {
                    ratio = NSDecimalNumber(decimal: actual / target).stringValue
                } else {
                    ratio = ""
                }
                return [
                    task.day.key,
                    task.id.uuidString.lowercased(),
                    task.title,
                    task.growthArea.rawValue,
                    task.state.rawValue,
                    decimal(target),
                    decimal(actual),
                    task.target?.unit ?? "",
                    ratio
                ]
            }
        return csv(header: header, rows: rows)
    }

    private static func badges(_ badges: [BadgeAwardSnapshot]) -> String {
        let header = ["badge_id", "profile_id", "awarded_at", "badge_code", "name", "source", "reason"]
        let rows = badges.sorted { $0.awardedAt < $1.awardedAt }.map { badge in
            [
                badge.id.uuidString.lowercased(),
                badge.profileID.uuidString.lowercased(),
                ISO8601DateFormatter().string(from: badge.awardedAt),
                badge.badgeCode,
                badge.name,
                badge.source.rawValue,
                badge.reason ?? ""
            ]
        }
        return csv(header: header, rows: rows)
    }

    private static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows)
            .map { $0.map(CSVFieldEncoder.escaped).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func decimal(_ value: Decimal?) -> String {
        value.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }

}
