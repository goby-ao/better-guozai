import Foundation

public struct ProfileSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let nickname: String
    public let avatarData: Data?
    public let avatarSymbol: String?
    public let currentGrade: String?

    public init(
        id: UUID,
        nickname: String,
        avatarData: Data? = nil,
        avatarSymbol: String? = nil,
        currentGrade: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarData = avatarData
        self.avatarSymbol = avatarSymbol
        self.currentGrade = currentGrade
    }
}

public struct TagSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let name: String
    public let createdAt: Date?

    public init(id: UUID, profileID: UUID, name: String, createdAt: Date? = nil) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.createdAt = createdAt
    }
}

public struct DailyPlanSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let day: LocalDay
    public let generatedAt: Date
    public let lastModifiedAt: Date

    public init(
        id: UUID,
        profileID: UUID,
        day: LocalDay,
        generatedAt: Date,
        lastModifiedAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.day = day
        self.generatedAt = generatedAt
        self.lastModifiedAt = lastModifiedAt
    }
}

public struct DailyReflectionSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let day: LocalDay
    public let mood: String?
    public let selfRating: Int?
    public let proudMoment: String?
    public let parentEncouragement: String?
    public let correctedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        profileID: UUID,
        day: LocalDay,
        mood: String? = nil,
        selfRating: Int? = nil,
        proudMoment: String? = nil,
        parentEncouragement: String? = nil,
        correctedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.day = day
        self.mood = mood
        self.selfRating = selfRating
        self.proudMoment = proudMoment
        self.parentEncouragement = parentEncouragement
        self.correctedAt = correctedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BadgeAwardSnapshot: Codable, Hashable, Identifiable, Sendable {
    public enum Source: String, Codable, CaseIterable, Sendable {
        case system
        case special
    }

    public let id: UUID
    public let profileID: UUID
    public let badgeCode: String
    public let name: String
    public let source: Source
    public let awardedAt: Date
    public let ruleVersion: Int?
    public let evidenceRecordIDs: [UUID]
    public let reason: String?
    public let symbol: String?

    public init(
        id: UUID,
        profileID: UUID,
        badgeCode: String,
        name: String,
        source: Source,
        awardedAt: Date,
        ruleVersion: Int? = nil,
        evidenceRecordIDs: [UUID] = [],
        reason: String? = nil,
        symbol: String? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.badgeCode = badgeCode
        self.name = name
        self.source = source
        self.awardedAt = awardedAt
        self.ruleVersion = ruleVersion
        self.evidenceRecordIDs = evidenceRecordIDs
        self.reason = reason
        self.symbol = symbol
    }
}

public struct WishRewardSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let name: String
    public let linkedBadgeCode: String?
    public let targetDescription: String?
    public let weeklyTarget: Int?
    public let selectedAt: Date?
    public let unlockedAt: Date?
    public let claimedAt: Date?
    public let createdAt: Date?

    public init(
        id: UUID,
        profileID: UUID,
        name: String,
        linkedBadgeCode: String? = nil,
        targetDescription: String? = nil,
        weeklyTarget: Int? = nil,
        selectedAt: Date? = nil,
        unlockedAt: Date? = nil,
        claimedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.linkedBadgeCode = linkedBadgeCode
        self.targetDescription = targetDescription
        self.weeklyTarget = weeklyTarget
        self.selectedAt = selectedAt
        self.unlockedAt = unlockedAt
        self.claimedAt = claimedAt
        self.createdAt = createdAt
    }
}
