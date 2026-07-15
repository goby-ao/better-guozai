import Foundation
import SwiftData
#if SWIFT_PACKAGE
import GuozaiCore
#endif

struct BackupPreview: Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let firstDay: LocalDay?
    let lastDay: LocalDay?
    let profileCount: Int
    let templateCount: Int
    let taskCount: Int
    let checkInCount: Int
    let reflectionCount: Int
    let badgeCount: Int
    let rewardCount: Int

    var dateRangeText: String {
        switch (firstDay, lastDay) {
        case let (first?, last?) where first == last:
            first.key
        case let (first?, last?):
            "\(first.key) 至 \(last.key)"
        default:
            "暂无每日记录"
        }
    }
}

struct BackupImportCandidate: Identifiable {
    let id = UUID()
    let payload: BackupPayload
    let preview: BackupPreview
}

struct BackupMergeResult: Equatable {
    var insertedProfiles = 0
    var insertedTags = 0
    var insertedTemplates = 0
    var insertedPlans = 0
    var insertedTasks = 0
    var insertedReflections = 0
    var insertedBadges = 0
    var insertedRewards = 0

    var skippedProfiles = 0
    var skippedTags = 0
    var skippedTemplates = 0
    var skippedPlans = 0
    var skippedTasks = 0
    var skippedReflections = 0
    var skippedBadges = 0
    var skippedRewards = 0

    var insertedTotal: Int {
        insertedProfiles + insertedTags + insertedTemplates + insertedPlans
            + insertedTasks + insertedReflections + insertedBadges + insertedRewards
    }

    var skippedTotal: Int {
        skippedProfiles + skippedTags + skippedTemplates + skippedPlans
            + skippedTasks + skippedReflections + skippedBadges + skippedRewards
    }
}

enum AppBackupError: LocalizedError {
    case invalidStoredDay(String)
    case singleProfileRequired(Int)
    case inconsistentProfileReference
    case multipleStoredProfiles(Int)

    var errorDescription: String? {
        switch self {
        case let .invalidStoredDay(dayKey):
            "本地记录包含无效日期：\(dayKey)"
        case let .singleProfileRequired(count):
            "备份中包含 \(count) 个成长档案；当前版本一次只能恢复一个果仔档案。"
        case .inconsistentProfileReference:
            "备份中存在无法归属到果仔档案的记录。"
        case let .multipleStoredProfiles(count):
            "本机已有 \(count) 个成长档案，请先升级到支持多档案的版本后再恢复。"
        }
    }
}

@MainActor
enum AppBackupService {
    static func makePayload(
        in context: ModelContext,
        exportedAt: Date = .now,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    ) throws -> BackupPayload {
        let profiles = try context.fetch(FetchDescriptor<ProfileRecord>())
        let tags = try context.fetch(FetchDescriptor<TagRecord>())
        let templates = try context.fetch(FetchDescriptor<TaskTemplateRecord>())
        let plans = try context.fetch(FetchDescriptor<DailyPlanRecord>())
        let tasks = try context.fetch(FetchDescriptor<DailyTaskRecord>())
        let reflections = try context.fetch(FetchDescriptor<DailyReflectionRecord>())
        let badges = try context.fetch(FetchDescriptor<BadgeAwardRecord>())
        let rewards = try context.fetch(FetchDescriptor<WishRewardRecord>())

        return BackupPayload(
            exportedAt: exportedAt,
            appVersion: appVersion,
            profiles: profiles.sorted(by: uuidOrder).map(profileSnapshot),
            tags: tags.sorted(by: uuidOrder).map(tagSnapshot),
            templates: try templates.sorted(by: uuidOrder).map(templateSnapshot),
            dailyPlans: try plans.sorted(by: dayThenUUIDOrder).map(planSnapshot),
            tasks: try tasks.sorted(by: taskOrder).map(taskSnapshot),
            reflections: try reflections.sorted(by: reflectionOrder).map(reflectionSnapshot),
            badgeAwards: badges.sorted { $0.awardedAt < $1.awardedAt }.map(badgeSnapshot),
            wishRewards: rewards.sorted(by: uuidOrder).map(rewardSnapshot)
        )
    }

    static func makeJSONDocument(in context: ModelContext) throws -> JSONBackupDocument {
        JSONBackupDocument(data: try BackupCodec.encode(makePayload(in: context)))
    }

    static func candidate(from data: Data) throws -> BackupImportCandidate {
        let payload = try BackupCodec.decode(data)
        _ = try validatedProfileID(in: payload)
        return BackupImportCandidate(payload: payload, preview: preview(for: payload))
    }

    static func preview(for payload: BackupPayload) -> BackupPreview {
        let days = payload.dailyPlans.map(\.day)
            + payload.tasks.map(\.day)
            + payload.reflections.map(\.day)
        return BackupPreview(
            schemaVersion: payload.schemaVersion,
            exportedAt: payload.exportedAt,
            appVersion: payload.appVersion,
            firstDay: days.min(),
            lastDay: days.max(),
            profileCount: payload.profiles.count,
            templateCount: payload.templates.count,
            taskCount: payload.tasks.count,
            checkInCount: payload.tasks.count { $0.state == .completed },
            reflectionCount: payload.reflections.count,
            badgeCount: payload.badgeAwards.count,
            rewardCount: payload.wishRewards.count
        )
    }

    /// Merges missing stable records into the single local profile. Only untouched seed scaffolding is replaced.
    static func merge(_ payload: BackupPayload, into context: ModelContext) throws -> BackupMergeResult {
        let importedProfileID = try validatedProfileID(in: payload)
        var result = BackupMergeResult()

        do {
            try context.transaction {
                let storedProfiles = try context.fetch(FetchDescriptor<ProfileRecord>())
                guard storedProfiles.count <= 1 else {
                    throw AppBackupError.multipleStoredProfiles(storedProfiles.count)
                }

                let existingProfile = storedProfiles.first
                let destinationProfileID = existingProfile?.id ?? importedProfileID
                func mappedProfileID(_ source: UUID) -> UUID {
                    source == importedProfileID ? destinationProfileID : source
                }

                if
                    let existingProfile,
                    try SeedService.isPristineScaffold(profile: existingProfile, in: context),
                    let importedProfile = payload.profiles.first
                {
                    try SeedService.removeScaffoldData(profileID: existingProfile.id, in: context)
                    context.processPendingChanges()
                    existingProfile.nickname = importedProfile.nickname
                    existingProfile.avatarSymbol = importedProfile.avatarSymbol ?? "face.smiling.fill"
                    existingProfile.grade = importedProfile.currentGrade
                    existingProfile.updatedAt = payload.exportedAt
                }

                var profileIDs = Set(try context.fetch(FetchDescriptor<ProfileRecord>()).map(\.id))
                for snapshot in payload.profiles {
                    let profileID = mappedProfileID(snapshot.id)
                    guard profileIDs.insert(profileID).inserted else {
                        result.skippedProfiles += 1
                        continue
                    }
                    context.insert(ProfileRecord(
                        id: profileID,
                        nickname: snapshot.nickname,
                        avatarSymbol: snapshot.avatarSymbol ?? "face.smiling.fill",
                        grade: snapshot.currentGrade
                    ))
                    result.insertedProfiles += 1
                }

                var tagIDs = Set(try context.fetch(FetchDescriptor<TagRecord>()).map(\.id))
                for snapshot in payload.tags {
                    guard tagIDs.insert(snapshot.id).inserted else {
                        result.skippedTags += 1
                        continue
                    }
                    context.insert(TagRecord(
                        id: snapshot.id,
                        profileId: mappedProfileID(snapshot.profileID),
                        name: snapshot.name,
                        createdAt: snapshot.createdAt ?? payload.exportedAt
                    ))
                    result.insertedTags += 1
                }

                var templateIDs = Set(try context.fetch(FetchDescriptor<TaskTemplateRecord>()).map(\.id))
                for (sortOrder, snapshot) in payload.templates.enumerated() {
                    guard templateIDs.insert(snapshot.id).inserted else {
                        result.skippedTemplates += 1
                        continue
                    }
                    let pause = snapshot.recurrence.pauses.first
                    context.insert(TaskTemplateRecord(
                        id: snapshot.id,
                        profileId: mappedProfileID(snapshot.profileID),
                        title: snapshot.title,
                        growthDomain: storedDomain(snapshot.growthArea),
                        tags: snapshot.tags,
                        requirement: storedRequirement(snapshot.requirement),
                        recurrenceKind: snapshot.recurrence.kind,
                        startDayKey: snapshot.recurrence.start.key,
                        endDayKey: snapshot.recurrence.end?.key,
                        weekdays: snapshot.recurrence.weekdays,
                        pauseStartDayKey: pause?.start.key,
                        pauseEndDayKey: pause?.end.key,
                        targetValue: double(snapshot.target?.amount),
                        targetUnit: snapshot.target?.unit,
                        reminderHour: snapshot.reminderHour,
                        reminderMinute: snapshot.reminderMinute,
                        sortOrder: snapshot.sortOrder ?? sortOrder,
                        isActive: snapshot.isActive ?? true,
                        createdAt: snapshot.createdAt ?? payload.exportedAt,
                        updatedAt: snapshot.updatedAt ?? payload.exportedAt,
                        deletedAt: snapshot.deletedAt
                    ))
                    result.insertedTemplates += 1
                }

                let storedPlans = try context.fetch(FetchDescriptor<DailyPlanRecord>())
                var planIDs = Set(storedPlans.map(\.id))
                var planIdentities = Set(storedPlans.map(\.identityKey))
                var planIDByIdentity = Dictionary(
                    uniqueKeysWithValues: storedPlans.map { ($0.identityKey, $0.id) }
                )

                for snapshot in payload.dailyPlans {
                    let profileID = mappedProfileID(snapshot.profileID)
                    let identity = DailyPlanRecord.makeIdentityKey(
                        profileId: profileID,
                        dayKey: snapshot.day.key
                    )
                    guard !planIDs.contains(snapshot.id), !planIdentities.contains(identity) else {
                        result.skippedPlans += 1
                        continue
                    }
                    let record = DailyPlanRecord(
                        id: snapshot.id,
                        profileId: profileID,
                        dayKey: snapshot.day.key,
                        generatedAt: snapshot.generatedAt,
                        updatedAt: snapshot.lastModifiedAt
                    )
                    context.insert(record)
                    planIDs.insert(snapshot.id)
                    planIdentities.insert(identity)
                    planIDByIdentity[identity] = snapshot.id
                    result.insertedPlans += 1
                }

                let storedTasks = try context.fetch(FetchDescriptor<DailyTaskRecord>())
                var taskIDs = Set(storedTasks.map(\.id))
                var taskIdentities = Set(storedTasks.map(\.identityKey))
                for (sortOrder, snapshot) in payload.tasks.enumerated() {
                    let profileID = mappedProfileID(snapshot.profileID)
                    let taskIdentity: String
                    if snapshot.source == .template, let templateID = snapshot.templateID {
                        taskIdentity = DailyTaskRecord.templateIdentity(
                            dayKey: snapshot.day.key,
                            templateId: templateID
                        )
                    } else {
                        taskIdentity = "backup|\(snapshot.id.uuidString)"
                    }
                    guard
                        !taskIDs.contains(snapshot.id),
                        !taskIdentities.contains(taskIdentity)
                    else {
                        result.skippedTasks += 1
                        continue
                    }

                    let planIdentity = DailyPlanRecord.makeIdentityKey(
                        profileId: profileID,
                        dayKey: snapshot.day.key
                    )
                    let planID: UUID
                    if let existingPlanID = planIDByIdentity[planIdentity] {
                        planID = existingPlanID
                    } else {
                        let newPlan = DailyPlanRecord(
                            profileId: profileID,
                            dayKey: snapshot.day.key,
                            generatedAt: payload.exportedAt,
                            updatedAt: payload.exportedAt
                        )
                        context.insert(newPlan)
                        planIDByIdentity[planIdentity] = newPlan.id
                        planIDs.insert(newPlan.id)
                        planIdentities.insert(planIdentity)
                        planID = newPlan.id
                        result.insertedPlans += 1
                    }

                    context.insert(DailyTaskRecord(
                        id: snapshot.id,
                        identityKey: taskIdentity,
                        planId: planID,
                        profileId: profileID,
                        dayKey: snapshot.day.key,
                        templateId: snapshot.templateID,
                        title: snapshot.title,
                        growthDomain: storedDomain(snapshot.growthArea),
                        tags: snapshot.tags,
                        requirement: storedRequirement(snapshot.requirement),
                        origin: storedOrigin(snapshot.source),
                        status: storedStatus(snapshot.state),
                        targetValue: double(snapshot.target?.amount),
                        targetUnit: snapshot.target?.unit,
                        actualValue: double(snapshot.actualQuantity),
                        sortOrder: snapshot.sortOrder ?? sortOrder,
                        completedAt: snapshot.completedAt,
                        skippedAt: snapshot.skippedAt ?? (snapshot.state == .skipped ? payload.exportedAt : nil),
                        skipReason: snapshot.skipReason,
                        correctedAt: snapshot.correctedAt,
                        createdAt: snapshot.createdAt ?? snapshot.completedAt ?? payload.exportedAt,
                        updatedAt: snapshot.updatedAt ?? snapshot.correctedAt ?? snapshot.completedAt ?? payload.exportedAt
                    ))
                    taskIDs.insert(snapshot.id)
                    taskIdentities.insert(taskIdentity)
                    result.insertedTasks += 1
                }

                let storedReflections = try context.fetch(FetchDescriptor<DailyReflectionRecord>())
                var reflectionIDs = Set(storedReflections.map(\.id))
                var reflectionIdentities = Set(storedReflections.map(\.identityKey))
                for snapshot in payload.reflections {
                    let profileID = mappedProfileID(snapshot.profileID)
                    let identity = "\(profileID.uuidString)|\(snapshot.day.key)"
                    guard
                        !reflectionIDs.contains(snapshot.id),
                        !reflectionIdentities.contains(identity)
                    else {
                        result.skippedReflections += 1
                        continue
                    }
                    context.insert(DailyReflectionRecord(
                        id: snapshot.id,
                        profileId: profileID,
                        dayKey: snapshot.day.key,
                        mood: storedMood(snapshot.mood),
                        rating: snapshot.selfRating,
                        proudMoment: snapshot.proudMoment ?? "",
                        parentEncouragement: snapshot.parentEncouragement ?? "",
                        createdAt: snapshot.createdAt ?? payload.exportedAt,
                        updatedAt: snapshot.updatedAt ?? snapshot.correctedAt ?? payload.exportedAt,
                        correctedAt: snapshot.correctedAt
                    ))
                    reflectionIDs.insert(snapshot.id)
                    reflectionIdentities.insert(identity)
                    result.insertedReflections += 1
                }

                let storedBadges = try context.fetch(FetchDescriptor<BadgeAwardRecord>())
                var badgeIDs = Set(storedBadges.map(\.id))
                var badgeIdentities = Set(storedBadges.map {
                    "\($0.profileId.uuidString)|\($0.source.rawValue)|\($0.stableBadgeId)"
                })
                for snapshot in payload.badgeAwards {
                    let profileID = mappedProfileID(snapshot.profileID)
                    let source: StoredBadgeSource = snapshot.source == .system ? .system : .parent
                    let identity = "\(profileID.uuidString)|\(source.rawValue)|\(snapshot.badgeCode)"
                    guard !badgeIDs.contains(snapshot.id), !badgeIdentities.contains(identity) else {
                        result.skippedBadges += 1
                        continue
                    }
                    context.insert(BadgeAwardRecord(
                        id: snapshot.id,
                        profileId: profileID,
                        stableBadgeId: snapshot.badgeCode,
                        title: snapshot.name,
                        detail: snapshot.reason ?? "",
                        symbol: snapshot.symbol ?? "medal.fill",
                        source: source,
                        ruleVersion: snapshot.ruleVersion,
                        evidenceIds: snapshot.evidenceRecordIDs,
                        awardedAt: snapshot.awardedAt
                    ))
                    badgeIDs.insert(snapshot.id)
                    badgeIdentities.insert(identity)
                    result.insertedBadges += 1
                }

                var rewardIDs = Set(try context.fetch(FetchDescriptor<WishRewardRecord>()).map(\.id))
                for snapshot in payload.wishRewards {
                    guard rewardIDs.insert(snapshot.id).inserted else {
                        result.skippedRewards += 1
                        continue
                    }
                    context.insert(WishRewardRecord(
                        id: snapshot.id,
                        profileId: mappedProfileID(snapshot.profileID),
                        title: snapshot.name,
                        detail: snapshot.targetDescription ?? "",
                        linkedBadgeId: snapshot.linkedBadgeCode,
                        weeklyTarget: snapshot.weeklyTarget,
                        state: storedWishState(snapshot),
                        unlockedAt: snapshot.unlockedAt,
                        claimedAt: snapshot.claimedAt,
                        createdAt: snapshot.createdAt ?? payload.exportedAt
                    ))
                    result.insertedRewards += 1
                }
            }
        } catch {
            context.rollback()
            throw error
        }

        return result
    }

    private static func validatedProfileID(in payload: BackupPayload) throws -> UUID {
        guard payload.profiles.count == 1, let profileID = payload.profiles.first?.id else {
            throw AppBackupError.singleProfileRequired(payload.profiles.count)
        }

        let referencedProfileIDs = Set(
            payload.tags.map(\.profileID)
                + payload.templates.map(\.profileID)
                + payload.dailyPlans.map(\.profileID)
                + payload.tasks.map(\.profileID)
                + payload.reflections.map(\.profileID)
                + payload.badgeAwards.map(\.profileID)
                + payload.wishRewards.map(\.profileID)
        )
        guard referencedProfileIDs.allSatisfy({ $0 == profileID }) else {
            throw AppBackupError.inconsistentProfileReference
        }
        return profileID
    }

    private static func profileSnapshot(_ record: ProfileRecord) -> ProfileSnapshot {
        ProfileSnapshot(
            id: record.id,
            nickname: record.nickname,
            avatarSymbol: record.avatarSymbol,
            currentGrade: record.grade
        )
    }

    private static func tagSnapshot(_ record: TagRecord) -> TagSnapshot {
        TagSnapshot(id: record.id, profileID: record.profileId, name: record.name, createdAt: record.createdAt)
    }

    private static func templateSnapshot(_ record: TaskTemplateRecord) throws -> TaskTemplateSnapshot {
        guard let start = LocalDay(key: record.startDayKey) else {
            throw AppBackupError.invalidStoredDay(record.startDayKey)
        }
        let pause: [RecurrenceRule.Pause]
        if
            let startKey = record.pauseStartDayKey,
            let endKey = record.pauseEndDayKey,
            let pauseStart = LocalDay(key: startKey),
            let pauseEnd = LocalDay(key: endKey)
        {
            pause = [.init(start: pauseStart, end: pauseEnd)]
        } else {
            pause = []
        }
        return TaskTemplateSnapshot(
            id: record.id,
            profileID: record.profileId,
            title: record.title,
            growthArea: growthArea(record.growthDomain),
            tags: record.tags,
            requirement: taskRequirement(record.requirement),
            recurrence: RecurrenceRule(
                kind: record.recurrenceKind,
                start: start,
                end: try optionalDay(record.endDayKey),
                weekdays: record.weekdays,
                pauses: pause
            ),
            target: quantityTarget(value: record.targetValue, unit: record.targetUnit),
            sortOrder: record.sortOrder,
            isActive: record.isActive,
            reminderHour: record.reminderHour,
            reminderMinute: record.reminderMinute,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            deletedAt: record.deletedAt
        )
    }

    private static func planSnapshot(_ record: DailyPlanRecord) throws -> DailyPlanSnapshot {
        DailyPlanSnapshot(
            id: record.id,
            profileID: record.profileId,
            day: try day(record.dayKey),
            generatedAt: record.generatedAt,
            lastModifiedAt: record.updatedAt
        )
    }

    private static func taskSnapshot(_ record: DailyTaskRecord) throws -> DailyTaskSnapshot {
        DailyTaskSnapshot(
            id: record.id,
            profileID: record.profileId,
            day: try day(record.dayKey),
            title: record.title,
            growthArea: growthArea(record.growthDomain),
            tags: record.tags,
            requirement: taskRequirement(record.requirement),
            source: taskSource(record.origin),
            templateID: record.templateId,
            target: quantityTarget(value: record.targetValue, unit: record.targetUnit),
            state: taskState(record.status),
            actualQuantity: record.actualValue.map { Decimal($0) },
            completedAt: record.completedAt,
            skippedAt: record.skippedAt,
            skipReason: record.skipReason,
            correctedAt: record.correctedAt,
            sortOrder: record.sortOrder,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func reflectionSnapshot(_ record: DailyReflectionRecord) throws -> DailyReflectionSnapshot {
        DailyReflectionSnapshot(
            id: record.id,
            profileID: record.profileId,
            day: try day(record.dayKey),
            mood: record.moodRaw,
            selfRating: record.rating,
            proudMoment: record.proudMoment.nilIfEmpty,
            parentEncouragement: record.parentEncouragement.nilIfEmpty,
            correctedAt: record.correctedAt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func badgeSnapshot(_ record: BadgeAwardRecord) -> BadgeAwardSnapshot {
        BadgeAwardSnapshot(
            id: record.id,
            profileID: record.profileId,
            badgeCode: record.stableBadgeId,
            name: record.title,
            source: record.source == .system ? .system : .special,
            awardedAt: record.awardedAt,
            ruleVersion: record.ruleVersion,
            evidenceRecordIDs: record.evidenceIdsStorage
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) },
            reason: record.detail.nilIfEmpty,
            symbol: record.symbol
        )
    }

    private static func rewardSnapshot(_ record: WishRewardRecord) -> WishRewardSnapshot {
        WishRewardSnapshot(
            id: record.id,
            profileID: record.profileId,
            name: record.title,
            linkedBadgeCode: record.linkedBadgeId,
            targetDescription: record.detail.nilIfEmpty,
            weeklyTarget: record.weeklyTarget,
            unlockedAt: record.unlockedAt,
            claimedAt: record.claimedAt,
            createdAt: record.createdAt
        )
    }

    private static func day(_ key: String) throws -> LocalDay {
        guard let value = LocalDay(key: key) else { throw AppBackupError.invalidStoredDay(key) }
        return value
    }

    private static func optionalDay(_ key: String?) throws -> LocalDay? {
        guard let key else { return nil }
        return try day(key)
    }

    private static func quantityTarget(value: Double?, unit: String?) -> QuantityTarget? {
        guard let value, let unit, !unit.isEmpty else { return nil }
        return QuantityTarget(amount: Decimal(value), unit: unit)
    }

    private static func growthArea(_ value: StoredGrowthDomain) -> GrowthArea {
        switch value {
        case .learning: .learning
        case .reading: .reading
        case .exercise: .exercise
        case .selfCare: .selfCare
        case .familyResponsibility: .familyResponsibility
        case .exploration: .interestExploration
        }
    }

    private static func storedDomain(_ value: GrowthArea) -> StoredGrowthDomain {
        switch value {
        case .learning: .learning
        case .reading: .reading
        case .exercise: .exercise
        case .selfCare: .selfCare
        case .familyResponsibility: .familyResponsibility
        case .interestExploration: .exploration
        }
    }

    private static func taskRequirement(_ value: StoredTaskRequirement) -> TaskRequirement {
        value == .required ? .required : .optional
    }

    private static func storedRequirement(_ value: TaskRequirement) -> StoredTaskRequirement {
        value == .required ? .required : .optional
    }

    private static func taskSource(_ value: StoredTaskOrigin) -> DailyTaskSource {
        switch value {
        case .template: .template
        case .parentOneOff: .parentOneOff
        case .childChallenge: .challenge
        }
    }

    private static func storedOrigin(_ value: DailyTaskSource) -> StoredTaskOrigin {
        switch value {
        case .template: .template
        case .parentOneOff: .parentOneOff
        case .challenge: .childChallenge
        }
    }

    private static func taskState(_ value: StoredTaskStatus) -> DailyTaskState {
        switch value {
        case .pending: .pending
        case .completed: .completed
        case .skipped: .skipped
        }
    }

    private static func storedStatus(_ value: DailyTaskState) -> StoredTaskStatus {
        switch value {
        case .pending: .pending
        case .completed: .completed
        case .skipped: .skipped
        }
    }

    private static func storedMood(_ rawValue: String?) -> StoredMood? {
        guard let rawValue else { return nil }
        if let mood = StoredMood(rawValue: rawValue) { return mood }
        return StoredMood.allCases.first { $0.title == rawValue }
    }

    private static func storedWishState(_ snapshot: WishRewardSnapshot) -> StoredWishState {
        if snapshot.claimedAt != nil { return .claimed }
        if snapshot.unlockedAt != nil { return .unlocked }
        return .locked
    }

    private static func double(_ value: Decimal?) -> Double? {
        value.map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    private static func uuidOrder<T>(_ lhs: T, _ rhs: T) -> Bool where T: AnyObject {
        uuid(of: lhs).uuidString < uuid(of: rhs).uuidString
    }

    private static func uuid(of record: AnyObject) -> UUID {
        switch record {
        case let value as ProfileRecord: value.id
        case let value as TagRecord: value.id
        case let value as TaskTemplateRecord: value.id
        case let value as WishRewardRecord: value.id
        default: UUID()
        }
    }

    private static func dayThenUUIDOrder(_ lhs: DailyPlanRecord, _ rhs: DailyPlanRecord) -> Bool {
        lhs.dayKey == rhs.dayKey ? lhs.id.uuidString < rhs.id.uuidString : lhs.dayKey < rhs.dayKey
    }

    private static func taskOrder(_ lhs: DailyTaskRecord, _ rhs: DailyTaskRecord) -> Bool {
        if lhs.dayKey != rhs.dayKey { return lhs.dayKey < rhs.dayKey }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func reflectionOrder(_ lhs: DailyReflectionRecord, _ rhs: DailyReflectionRecord) -> Bool {
        lhs.dayKey == rhs.dayKey ? lhs.id.uuidString < rhs.id.uuidString : lhs.dayKey < rhs.dayKey
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
