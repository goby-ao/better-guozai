import Foundation

public enum GrowthArea: String, Codable, CaseIterable, Sendable {
    case learning
    case reading
    case exercise
    case selfCare = "self-care"
    case familyResponsibility = "family-responsibility"
    case interestExploration = "interest-exploration"
}

public enum TaskRequirement: String, Codable, CaseIterable, Sendable {
    case required
    case optional
}

public struct QuantityTarget: Codable, Hashable, Sendable {
    public let amount: Decimal
    public let unit: String

    public init(amount: Decimal, unit: String) {
        self.amount = amount
        self.unit = unit
    }
}

public struct TaskTemplateSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let title: String
    public let growthArea: GrowthArea
    public let tags: [String]
    public let requirement: TaskRequirement
    public let recurrence: RecurrenceRule
    public let target: QuantityTarget?
    public let sortOrder: Int?
    public let isActive: Bool?
    public let reminderHour: Int?
    public let reminderMinute: Int?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let deletedAt: Date?

    public init(
        id: UUID,
        profileID: UUID,
        title: String,
        growthArea: GrowthArea,
        tags: [String] = [],
        requirement: TaskRequirement,
        recurrence: RecurrenceRule,
        target: QuantityTarget? = nil,
        sortOrder: Int? = nil,
        isActive: Bool? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.title = title
        self.growthArea = growthArea
        self.tags = tags
        self.requirement = requirement
        self.recurrence = recurrence
        self.target = target
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public enum DailyTaskSource: String, Codable, CaseIterable, Sendable {
    case template
    case parentOneOff = "parent-one-off"
    case challenge
}

public enum DailyTaskState: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
    case skipped
}

public struct DailyTaskSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let day: LocalDay
    public let title: String
    public let growthArea: GrowthArea
    public let tags: [String]
    public let requirement: TaskRequirement
    public let source: DailyTaskSource
    public let templateID: UUID?
    public let target: QuantityTarget?
    public let state: DailyTaskState
    public let actualQuantity: Decimal?
    public let completedAt: Date?
    public let skippedAt: Date?
    public let skipReason: String?
    public let correctedAt: Date?
    public let sortOrder: Int?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        profileID: UUID,
        day: LocalDay,
        title: String,
        growthArea: GrowthArea,
        tags: [String] = [],
        requirement: TaskRequirement,
        source: DailyTaskSource,
        templateID: UUID? = nil,
        target: QuantityTarget? = nil,
        state: DailyTaskState = .pending,
        actualQuantity: Decimal? = nil,
        completedAt: Date? = nil,
        skippedAt: Date? = nil,
        skipReason: String? = nil,
        correctedAt: Date? = nil,
        sortOrder: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.day = day
        self.title = title
        self.growthArea = growthArea
        self.tags = tags
        self.requirement = requirement
        self.source = source
        self.templateID = templateID
        self.target = target
        self.state = state
        self.actualQuantity = actualQuantity
        self.completedAt = completedAt
        self.skippedAt = skippedAt
        self.skipReason = skipReason
        self.correctedAt = correctedAt
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(id: UUID, day: LocalDay, template: TaskTemplateSnapshot) {
        self.init(
            id: id,
            profileID: template.profileID,
            day: day,
            title: template.title,
            growthArea: template.growthArea,
            tags: template.tags,
            requirement: template.requirement,
            source: .template,
            templateID: template.id,
            target: template.target
        )
    }
}
