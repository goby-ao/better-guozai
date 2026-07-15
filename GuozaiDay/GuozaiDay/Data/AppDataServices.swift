import Foundation
import SwiftData
#if SWIFT_PACKAGE
import GuozaiCore
#endif

@MainActor
enum SeedService {
    static let defaultProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!

    static let defaultTemplates: [DefaultTemplate] = [
        .init(idSuffix: 201, "早起洗漱，整理好自己的床铺", .selfCare, ["好习惯"]),
        .init(idSuffix: 202, "大声朗读或阅读 30 分钟", .reading, ["阅读"], target: 30, unit: "分钟"),
        .init(idSuffix: 203, "完成一页数学计算练习", .learning, ["数学"], target: 1, unit: "页"),
        .init(idSuffix: 204, "认真练字或完成一项语文任务", .learning, ["语文"]),
        .init(idSuffix: 205, "英语听读 20 分钟", .learning, ["英语"], target: 20, unit: "分钟"),
        .init(idSuffix: 206, "户外运动 60 分钟", .exercise, ["运动"], target: 60, unit: "分钟"),
        .init(idSuffix: 207, "做一件力所能及的家务", .familyResponsibility, ["生活"], target: 1, unit: "件"),
        .init(idSuffix: 208, "整理书桌和自己的物品", .selfCare, ["整理"], requirement: .optional),
        .init(idSuffix: 209, "睡前回顾今天，准备明天的用品", .exploration, ["复盘"], requirement: .optional),
    ]

    static func ensureSeeded(in context: ModelContext, today: LocalDay = LocalDay(date: .now)) throws -> ProfileRecord {
        if let profile = try context.fetch(FetchDescriptor<ProfileRecord>()).first {
            return profile
        }

        let profile = ProfileRecord(id: defaultProfileID)
        context.insert(profile)

        for (index, item) in defaultTemplates.enumerated() {
            context.insert(TaskTemplateRecord(
                id: item.id,
                profileId: profile.id,
                title: item.title,
                growthDomain: item.domain,
                tags: item.tags,
                requirement: item.requirement,
                startDayKey: today.key,
                targetValue: item.target,
                targetUnit: item.unit,
                sortOrder: index
            ))
        }

        for (index, tag) in Set(defaultTemplates.flatMap(\.tags)).sorted().enumerated() {
            let tagID = UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                301 + index
            ))!
            context.insert(TagRecord(id: tagID, profileId: profile.id, name: tag))
        }

        try PersistenceWriter.save(context)
        return profile
    }

    static func isPristineScaffold(profile: ProfileRecord, in context: ModelContext) throws -> Bool {
        guard
            profile.nickname == "果仔",
            profile.grade?.isEmpty != false,
            profile.avatarSymbol == nil || profile.avatarSymbol == "face.smiling.fill"
        else { return false }

        let profileID = profile.id
        let templates = try context.fetch(FetchDescriptor<TaskTemplateRecord>())
            .filter { $0.profileId == profileID }
        guard templates.count == defaultTemplates.count else { return false }

        let sortedTemplates = templates.sorted { $0.sortOrder < $1.sortOrder }
        guard zip(sortedTemplates, defaultTemplates).allSatisfy({ record, expected in
            record.title == expected.title
                && record.growthDomain == expected.domain
                && record.tags == expected.tags
                && record.requirement == expected.requirement
                && record.recurrenceKind == .daily
                && record.endDayKey == nil
                && record.weekdays.isEmpty
                && record.pauseStartDayKey == nil
                && record.pauseEndDayKey == nil
                && record.targetValue == expected.target
                && record.targetUnit == expected.unit
                && record.reminderHour == nil
                && record.reminderMinute == nil
                && record.isActive
                && record.deletedAt == nil
        }) else { return false }
        guard Set(templates.map(\.startDayKey)).count == 1 else { return false }

        let tasks = try context.fetch(FetchDescriptor<DailyTaskRecord>())
            .filter { $0.profileId == profileID }
        guard tasks.allSatisfy({
            $0.origin == .template && $0.status == .pending && $0.actualValue == nil
        }) else { return false }

        let reflections = try context.fetch(FetchDescriptor<DailyReflectionRecord>())
            .filter { $0.profileId == profileID }
        guard reflections.allSatisfy({
            $0.mood == nil && $0.rating == nil && $0.proudMoment.isEmpty
                && $0.parentEncouragement.isEmpty
        }) else { return false }

        let badges = try context.fetch(FetchDescriptor<BadgeAwardRecord>())
            .filter { $0.profileId == profileID }
        let rewards = try context.fetch(FetchDescriptor<WishRewardRecord>())
            .filter { $0.profileId == profileID }
        return badges.isEmpty && rewards.isEmpty
    }

    static func removeScaffoldData(profileID: UUID, in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<TagRecord>()) where record.profileId == profileID {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<TaskTemplateRecord>()) where record.profileId == profileID {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<DailyTaskRecord>()) where record.profileId == profileID {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<DailyPlanRecord>()) where record.profileId == profileID {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<DailyReflectionRecord>()) where record.profileId == profileID {
            context.delete(record)
        }
    }

    struct DefaultTemplate {
        let id: UUID
        let title: String
        let domain: StoredGrowthDomain
        let tags: [String]
        let target: Double?
        let unit: String?
        let requirement: StoredTaskRequirement

        init(
            idSuffix: Int,
            _ title: String,
            _ domain: StoredGrowthDomain,
            _ tags: [String],
            target: Double? = nil,
            unit: String? = nil,
            requirement: StoredTaskRequirement = .required
        ) {
            self.id = UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                idSuffix
            ))!
            self.title = title
            self.domain = domain
            self.tags = tags
            self.target = target
            self.unit = unit
            self.requirement = requirement
        }
    }
}

@MainActor
enum DailyPlanStore {
    @discardableResult
    static func syncCurrentPlanFromTemplates(
        for day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext,
        now: Date = .now
    ) throws -> DailyPlanRecord {
        try preparePlan(
            for: day,
            profile: profile,
            in: context,
            now: now,
            syncPendingTemplateTasks: true
        )
    }

    static func syncCurrentPlanFromTemplates(
        for day: LocalDay,
        profileID: UUID,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let descriptor = FetchDescriptor<ProfileRecord>(
            predicate: #Predicate { $0.id == profileID }
        )
        guard let profile = try context.fetch(descriptor).first else {
            try PersistenceWriter.save(context)
            return
        }
        try syncCurrentPlanFromTemplates(
            for: day,
            profile: profile,
            in: context,
            now: now
        )
    }

    @discardableResult
    static func ensurePlan(
        for day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext,
        now: Date = .now
    ) throws -> DailyPlanRecord {
        try preparePlan(
            for: day,
            profile: profile,
            in: context,
            now: now,
            syncPendingTemplateTasks: false
        )
    }

    private static func preparePlan(
        for day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext,
        now: Date,
        syncPendingTemplateTasks: Bool
    ) throws -> DailyPlanRecord {
        let profileId = profile.id
        let dayKey = day.key
        let plan = try ensurePlanRecord(
            for: day,
            profile: profile,
            in: context,
            now: now
        )

        let templateDescriptor = FetchDescriptor<TaskTemplateRecord>(
            predicate: #Predicate { $0.profileId == profileId },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let existingTaskDescriptor = FetchDescriptor<DailyTaskRecord>(
            predicate: #Predicate { $0.profileId == profileId && $0.dayKey == dayKey }
        )
        let allTemplates = try context.fetch(templateDescriptor)
        let templates = allTemplates
            .filter { $0.isActive && $0.deletedAt == nil }
        let existingTasks = try context.fetch(existingTaskDescriptor)
        let existingKeys = Set(existingTasks.map(\.identityKey))
        let missingTemplateIDs = Set(DailyPlanGenerator.missingTemplates(
            for: day,
            templates: templates.compactMap(\.coreSnapshot),
            existingTasks: existingTasks.compactMap(\.coreSnapshot)
        ).map(\.id))

        for template in templates where missingTemplateIDs.contains(template.id) {
            let taskIdentity = DailyTaskRecord.templateIdentity(dayKey: dayKey, templateId: template.id)
            guard !existingKeys.contains(taskIdentity) else { continue }
            context.insert(DailyTaskRecord(
                identityKey: taskIdentity,
                planId: plan.id,
                profileId: profileId,
                dayKey: dayKey,
                templateId: template.id,
                title: template.title,
                growthDomain: template.growthDomain,
                tags: template.tags,
                requirement: template.requirement,
                origin: .template,
                targetValue: template.targetValue,
                targetUnit: template.targetUnit,
                sortOrder: template.sortOrder,
                createdAt: now,
                updatedAt: now
            ))
        }

        if syncPendingTemplateTasks {
            let templatesByID = Dictionary(uniqueKeysWithValues: allTemplates.map { ($0.id, $0) })
            for task in existingTasks where task.origin == .template && task.status == .pending {
                guard let templateID = task.templateId else { continue }
                guard
                    let template = templatesByID[templateID],
                    template.isActive,
                    template.deletedAt == nil,
                    template.applies(to: day)
                else {
                    context.delete(task)
                    continue
                }

                task.title = template.title
                task.growthDomain = template.growthDomain
                task.tags = template.tags
                task.requirement = template.requirement
                task.targetValue = template.targetValue
                task.targetUnit = template.targetUnit
                task.sortOrder = template.sortOrder
                task.updatedAt = now
            }
        }

        plan.updatedAt = now
        try PersistenceWriter.save(context)
        return plan
    }

    static func addOneOffTask(
        title: String,
        domain: StoredGrowthDomain,
        requirement: StoredTaskRequirement,
        origin: StoredTaskOrigin,
        day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext
    ) throws {
        let plan = try ensurePlanRecord(for: day, profile: profile, in: context)
        let dayKey = day.key
        let profileId = profile.id
        let taskCount = try context.fetchCount(FetchDescriptor<DailyTaskRecord>(
            predicate: #Predicate { $0.profileId == profileId && $0.dayKey == dayKey }
        ))
        context.insert(DailyTaskRecord(
            planId: plan.id,
            profileId: profileId,
            dayKey: dayKey,
            title: title,
            growthDomain: domain,
            requirement: requirement,
            origin: origin,
            sortOrder: taskCount
        ))
        try PersistenceWriter.save(context)
    }

    private static func ensurePlanRecord(
        for day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext,
        now: Date = .now
    ) throws -> DailyPlanRecord {
        let identity = DailyPlanRecord.makeIdentityKey(profileId: profile.id, dayKey: day.key)
        let descriptor = FetchDescriptor<DailyPlanRecord>(
            predicate: #Predicate { $0.identityKey == identity }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let plan = DailyPlanRecord(
            profileId: profile.id,
            dayKey: day.key,
            generatedAt: now,
            updatedAt: now
        )
        context.insert(plan)
        return plan
    }

    @discardableResult
    static func ensureReflection(
        for day: LocalDay,
        profile: ProfileRecord,
        in context: ModelContext
    ) throws -> DailyReflectionRecord {
        let identity = "\(profile.id.uuidString)|\(day.key)"
        let descriptor = FetchDescriptor<DailyReflectionRecord>(
            predicate: #Predicate { $0.identityKey == identity }
        )
        if let reflection = try context.fetch(descriptor).first {
            return reflection
        }
        let reflection = DailyReflectionRecord(profileId: profile.id, dayKey: day.key)
        context.insert(reflection)
        try PersistenceWriter.save(context)
        return reflection
    }
}

@MainActor
enum CheckInService {
    static func toggleCompletion(
        _ task: DailyTaskRecord,
        actualValue: Double? = nil,
        now: Date = .now,
        today: LocalDay = LocalDay(date: .now),
        in context: ModelContext
    ) throws {
        if task.status == .completed {
            task.status = .pending
            task.completedAt = nil
            task.actualValue = nil
        } else {
            task.status = .completed
            task.completedAt = now
            task.skippedAt = nil
            task.skipReason = nil
            task.actualValue = actualValue ?? task.targetValue
        }
        if task.dayKey != today.key {
            task.correctedAt = now
        }
        task.updatedAt = now
        try PersistenceWriter.save(context)
    }

    static func skip(
        _ task: DailyTaskRecord,
        reason: String,
        now: Date = .now,
        today: LocalDay = LocalDay(date: .now),
        in context: ModelContext
    ) throws {
        task.status = .skipped
        task.skippedAt = now
        task.skipReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        task.completedAt = nil
        task.actualValue = nil
        if task.dayKey != today.key {
            task.correctedAt = now
        }
        task.updatedAt = now
        try PersistenceWriter.save(context)
    }

    static func reset(_ task: DailyTaskRecord, in context: ModelContext) throws {
        task.status = .pending
        task.completedAt = nil
        task.skippedAt = nil
        task.skipReason = nil
        task.actualValue = nil
        task.updatedAt = .now
        try PersistenceWriter.save(context)
    }
}

struct StoredDailyProgress {
    let completedCount: Int
    let totalCount: Int
    let requiredCompletedCount: Int
    let requiredTotalCount: Int

    init(tasks: [DailyTaskRecord]) {
        let progress = DailyProgress(tasks: tasks.compactMap(\.coreSnapshot))
        completedCount = progress.completedCount
        totalCount = progress.taskCount
        requiredCompletedCount = progress.completedRequiredCount
        requiredTotalCount = progress.requiredCount
    }

    var completionFraction: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    var requiredCompletionFraction: Double {
        requiredTotalCount == 0
            ? 0
            : Double(requiredCompletedCount) / Double(requiredTotalCount)
    }

    var isAchieved: Bool {
        requiredTotalCount > 0 && requiredCompletedCount == requiredTotalCount
    }
}
