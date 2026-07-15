import Foundation
import SwiftData
#if SWIFT_PACKAGE
import GuozaiCore
#endif

enum StoredGrowthDomain: String, Codable, CaseIterable, Identifiable {
    case learning
    case reading
    case exercise
    case selfCare
    case familyResponsibility
    case exploration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learning: "学习"
        case .reading: "阅读"
        case .exercise: "运动"
        case .selfCare: "生活自理"
        case .familyResponsibility: "家庭责任"
        case .exploration: "兴趣探索"
        }
    }
}

enum StoredTaskRequirement: String, Codable, CaseIterable, Identifiable {
    case required
    case optional

    var id: String { rawValue }
    var title: String { self == .required ? "必做" : "选做" }
}

enum StoredTaskStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case skipped
}

enum StoredTaskOrigin: String, Codable {
    case template
    case parentOneOff
    case childChallenge
}

enum StoredMood: String, Codable, CaseIterable, Identifiable {
    case sunny
    case happy
    case calm
    case tired
    case cloudy
    case veryUnhappy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunny: "超开心"
        case .happy: "开心"
        case .calm: "平静"
        case .tired: "有点累"
        case .cloudy: "不太开心"
        case .veryUnhappy: "很不开心"
        }
    }

    var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .happy: "face.smiling.fill"
        case .calm: "leaf.fill"
        case .tired: "moon.zzz.fill"
        case .cloudy: "cloud.rain.fill"
        case .veryUnhappy: "cloud.heavyrain.fill"
        }
    }
}

enum StoredBadgeSource: String, Codable {
    case system
    case parent
}

enum StoredWishState: String, Codable, CaseIterable {
    case locked
    case unlocked
    case claimed
}

@Model
final class ProfileRecord {
    @Attribute(.unique) var id: UUID
    var nickname: String
    var avatarSymbol: String?
    var grade: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        nickname: String = "果仔",
        avatarSymbol: String? = "face.smiling.fill",
        grade: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarSymbol = avatarSymbol
        self.grade = grade
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class TaskTemplateRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var title: String
    var growthDomainRaw: String
    var tagsStorage: String
    var requirementRaw: String
    var recurrenceKindRaw: String
    var startDayKey: String
    var endDayKey: String?
    var weekdaysStorage: String
    var pauseStartDayKey: String?
    var pauseEndDayKey: String?
    var targetValue: Double?
    var targetUnit: String?
    var reminderHour: Int?
    var reminderMinute: Int?
    var sortOrder: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        profileId: UUID,
        title: String,
        growthDomain: StoredGrowthDomain,
        tags: [String] = [],
        requirement: StoredTaskRequirement = .required,
        recurrenceKind: RecurrenceRule.Kind = .daily,
        startDayKey: String,
        endDayKey: String? = nil,
        weekdays: Set<Int> = [],
        pauseStartDayKey: String? = nil,
        pauseEndDayKey: String? = nil,
        targetValue: Double? = nil,
        targetUnit: String? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        sortOrder: Int = 0,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.title = title
        self.growthDomainRaw = growthDomain.rawValue
        self.tagsStorage = tags.joined(separator: Self.valueSeparator)
        self.requirementRaw = requirement.rawValue
        self.recurrenceKindRaw = recurrenceKind.rawValue
        self.startDayKey = startDayKey
        self.endDayKey = endDayKey
        self.weekdaysStorage = weekdays.sorted().map(String.init).joined(separator: ",")
        self.pauseStartDayKey = pauseStartDayKey
        self.pauseEndDayKey = pauseEndDayKey
        self.targetValue = targetValue
        self.targetUnit = targetUnit
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var growthDomain: StoredGrowthDomain {
        get { StoredGrowthDomain(rawValue: growthDomainRaw) ?? .learning }
        set { growthDomainRaw = newValue.rawValue }
    }

    var tags: [String] {
        get { tagsStorage.isEmpty ? [] : tagsStorage.components(separatedBy: Self.valueSeparator) }
        set { tagsStorage = newValue.joined(separator: Self.valueSeparator) }
    }

    var requirement: StoredTaskRequirement {
        get { StoredTaskRequirement(rawValue: requirementRaw) ?? .required }
        set { requirementRaw = newValue.rawValue }
    }

    var recurrenceKind: RecurrenceRule.Kind {
        get { RecurrenceRule.Kind(rawValue: recurrenceKindRaw) ?? .daily }
        set { recurrenceKindRaw = newValue.rawValue }
    }

    var weekdays: Set<Int> {
        get { Set(weekdaysStorage.split(separator: ",").compactMap { Int($0) }) }
        set { weekdaysStorage = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    func applies(to day: LocalDay, calendar: Calendar = .guozaiGregorian) -> Bool {
        guard isActive, deletedAt == nil, let start = LocalDay(key: startDayKey) else { return false }
        if
            let pauseStartDayKey,
            let pauseStart = LocalDay(key: pauseStartDayKey),
            day >= pauseStart,
            pauseEndDayKey.flatMap(LocalDay.init(key:)).map({ day <= $0 }) ?? true
        {
            return false
        }

        return RecurrenceRule(
            kind: recurrenceKind,
            start: start,
            end: endDayKey.flatMap(LocalDay.init(key:)),
            weekdays: weekdays
        ).applies(to: day, calendar: calendar)
    }

    private static let valueSeparator = "\u{001F}"
}

@Model
final class DailyPlanRecord {
    @Attribute(.unique) var identityKey: String
    var id: UUID
    var profileId: UUID
    var dayKey: String
    var generatedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        profileId: UUID,
        dayKey: String,
        generatedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.identityKey = Self.makeIdentityKey(profileId: profileId, dayKey: dayKey)
        self.id = id
        self.profileId = profileId
        self.dayKey = dayKey
        self.generatedAt = generatedAt
        self.updatedAt = updatedAt
    }

    static func makeIdentityKey(profileId: UUID, dayKey: String) -> String {
        "\(profileId.uuidString)|\(dayKey)"
    }
}

@Model
final class DailyTaskRecord {
    @Attribute(.unique) var identityKey: String
    var id: UUID
    var planId: UUID
    var profileId: UUID
    var dayKey: String
    var templateId: UUID?
    var title: String
    var growthDomainRaw: String
    var tagsStorage: String
    var requirementRaw: String
    var originRaw: String
    var statusRaw: String
    var targetValue: Double?
    var targetUnit: String?
    var actualValue: Double?
    var sortOrder: Int
    var completedAt: Date?
    var skippedAt: Date?
    var skipReason: String?
    var correctedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        identityKey: String? = nil,
        planId: UUID,
        profileId: UUID,
        dayKey: String,
        templateId: UUID? = nil,
        title: String,
        growthDomain: StoredGrowthDomain,
        tags: [String] = [],
        requirement: StoredTaskRequirement = .required,
        origin: StoredTaskOrigin = .template,
        status: StoredTaskStatus = .pending,
        targetValue: Double? = nil,
        targetUnit: String? = nil,
        actualValue: Double? = nil,
        sortOrder: Int = 0,
        completedAt: Date? = nil,
        skippedAt: Date? = nil,
        skipReason: String? = nil,
        correctedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.identityKey = identityKey ?? "task|\(id.uuidString)"
        self.planId = planId
        self.profileId = profileId
        self.dayKey = dayKey
        self.templateId = templateId
        self.title = title
        self.growthDomainRaw = growthDomain.rawValue
        self.tagsStorage = tags.joined(separator: Self.valueSeparator)
        self.requirementRaw = requirement.rawValue
        self.originRaw = origin.rawValue
        self.statusRaw = status.rawValue
        self.targetValue = targetValue
        self.targetUnit = targetUnit
        self.actualValue = actualValue
        self.sortOrder = sortOrder
        self.completedAt = completedAt
        self.skippedAt = skippedAt
        self.skipReason = skipReason
        self.correctedAt = correctedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var growthDomain: StoredGrowthDomain {
        get { StoredGrowthDomain(rawValue: growthDomainRaw) ?? .learning }
        set { growthDomainRaw = newValue.rawValue }
    }

    var tags: [String] {
        get { tagsStorage.isEmpty ? [] : tagsStorage.components(separatedBy: Self.valueSeparator) }
        set { tagsStorage = newValue.joined(separator: Self.valueSeparator) }
    }

    var requirement: StoredTaskRequirement {
        get { StoredTaskRequirement(rawValue: requirementRaw) ?? .required }
        set { requirementRaw = newValue.rawValue }
    }

    var origin: StoredTaskOrigin {
        get { StoredTaskOrigin(rawValue: originRaw) ?? .template }
        set { originRaw = newValue.rawValue }
    }

    var status: StoredTaskStatus {
        get { StoredTaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var isCompleted: Bool { status == .completed }

    static func templateIdentity(dayKey: String, templateId: UUID) -> String {
        "template|\(dayKey)|\(templateId.uuidString)"
    }

    private static let valueSeparator = "\u{001F}"
}

@Model
final class DailyReflectionRecord {
    @Attribute(.unique) var identityKey: String
    var id: UUID
    var profileId: UUID
    var dayKey: String
    var moodRaw: String?
    var rating: Int?
    var proudMoment: String
    var parentEncouragement: String
    var createdAt: Date
    var updatedAt: Date
    var correctedAt: Date?

    init(
        id: UUID = UUID(),
        profileId: UUID,
        dayKey: String,
        mood: StoredMood? = nil,
        rating: Int? = nil,
        proudMoment: String = "",
        parentEncouragement: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        correctedAt: Date? = nil
    ) {
        self.identityKey = "\(profileId.uuidString)|\(dayKey)"
        self.id = id
        self.profileId = profileId
        self.dayKey = dayKey
        self.moodRaw = mood?.rawValue
        self.rating = rating
        self.proudMoment = proudMoment
        self.parentEncouragement = parentEncouragement
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.correctedAt = correctedAt
    }

    var mood: StoredMood? {
        get { moodRaw.flatMap(StoredMood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }
}

@Model
final class BadgeAwardRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var stableBadgeId: String
    var title: String
    var detail: String
    var symbol: String
    var sourceRaw: String
    var ruleVersion: Int?
    var evidenceIdsStorage: String
    var awardedAt: Date

    init(
        id: UUID = UUID(),
        profileId: UUID,
        stableBadgeId: String,
        title: String,
        detail: String,
        symbol: String,
        source: StoredBadgeSource,
        ruleVersion: Int? = nil,
        evidenceIds: [UUID] = [],
        awardedAt: Date = .now
    ) {
        self.id = id
        self.profileId = profileId
        self.stableBadgeId = stableBadgeId
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.sourceRaw = source.rawValue
        self.ruleVersion = ruleVersion
        self.evidenceIdsStorage = evidenceIds.map(\.uuidString).joined(separator: ",")
        self.awardedAt = awardedAt
    }

    var source: StoredBadgeSource {
        get { StoredBadgeSource(rawValue: sourceRaw) ?? .system }
        set { sourceRaw = newValue.rawValue }
    }
}

@Model
final class WishRewardRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var title: String
    var detail: String
    var linkedBadgeId: String?
    var weeklyTarget: Int?
    var stateRaw: String
    var unlockedAt: Date?
    var claimedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        profileId: UUID,
        title: String,
        detail: String = "",
        linkedBadgeId: String? = nil,
        weeklyTarget: Int? = nil,
        state: StoredWishState = .locked,
        unlockedAt: Date? = nil,
        claimedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.profileId = profileId
        self.title = title
        self.detail = detail
        self.linkedBadgeId = linkedBadgeId
        self.weeklyTarget = weeklyTarget
        self.stateRaw = state.rawValue
        self.unlockedAt = unlockedAt
        self.claimedAt = claimedAt
        self.createdAt = createdAt
    }

    var state: StoredWishState {
        get { StoredWishState(rawValue: stateRaw) ?? .locked }
        set { stateRaw = newValue.rawValue }
    }
}

@Model
final class TagRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), profileId: UUID, name: String, createdAt: Date = .now) {
        self.id = id
        self.profileId = profileId
        self.name = name
        self.createdAt = createdAt
    }
}

@MainActor
enum PersistenceModels {
    static let schema = Schema([
        ProfileRecord.self,
        TaskTemplateRecord.self,
        DailyPlanRecord.self,
        DailyTaskRecord.self,
        DailyReflectionRecord.self,
        BadgeAwardRecord.self,
        WishRewardRecord.self,
        TagRecord.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
enum PersistenceWriter {
    static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
