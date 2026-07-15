import Foundation

public struct BackupPayload: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String
    public let profiles: [ProfileSnapshot]
    public let tags: [TagSnapshot]
    public let templates: [TaskTemplateSnapshot]
    public let dailyPlans: [DailyPlanSnapshot]
    public let tasks: [DailyTaskSnapshot]
    public let reflections: [DailyReflectionSnapshot]
    public let badgeAwards: [BadgeAwardSnapshot]
    public let wishRewards: [WishRewardSnapshot]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        exportedAt: Date,
        appVersion: String,
        profiles: [ProfileSnapshot] = [],
        tags: [TagSnapshot] = [],
        templates: [TaskTemplateSnapshot] = [],
        dailyPlans: [DailyPlanSnapshot] = [],
        tasks: [DailyTaskSnapshot] = [],
        reflections: [DailyReflectionSnapshot] = [],
        badgeAwards: [BadgeAwardSnapshot] = [],
        wishRewards: [WishRewardSnapshot] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.profiles = profiles
        self.tags = tags
        self.templates = templates
        self.dailyPlans = dailyPlans
        self.tasks = tasks
        self.reflections = reflections
        self.badgeAwards = badgeAwards
        self.wishRewards = wishRewards
    }
}

public enum BackupCodecError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
}

public enum BackupCodec {
    public static func encode(_ payload: BackupPayload) throws -> Data {
        try validate(schemaVersion: payload.schemaVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(StableISO8601.string(from: date))
        }
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> BackupPayload {
        let envelope = try JSONDecoder().decode(VersionEnvelope.self, from: data)
        try validate(schemaVersion: envelope.schemaVersion)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = StableISO8601.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO 8601 date: \(value)"
                )
            }
            return date
        }
        let payload = try decoder.decode(BackupPayload.self, from: data)
        return payload
    }

    private static func validate(schemaVersion: Int) throws {
        guard schemaVersion == BackupPayload.currentSchemaVersion else {
            throw BackupCodecError.unsupportedSchemaVersion(schemaVersion)
        }
    }

    private struct VersionEnvelope: Decodable {
        let schemaVersion: Int
    }
}

enum StableISO8601 {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
