import Foundation
import SwiftData

@MainActor
enum AchievementStore {
    static let ruleVersion = 1

    @discardableResult
    static func evaluate(profileId: UUID, in context: ModelContext) throws -> [BadgeAwardRecord] {
        let taskRecords = try context.fetch(FetchDescriptor<DailyTaskRecord>())
            .filter { $0.profileId == profileId }
        let snapshots = taskRecords.compactMap(\.coreSnapshot)
        let awardRecords = try context.fetch(FetchDescriptor<BadgeAwardRecord>())
            .filter { $0.profileId == profileId && $0.source == .system }
        let alreadyAwarded = Set(awardRecords.compactMap { BadgeCode(rawValue: $0.stableBadgeId) })
        let pending = BadgeEvaluator.pendingAwards(
            for: profileId,
            tasks: snapshots,
            alreadyAwarded: alreadyAwarded
        )

        var inserted: [BadgeAwardRecord] = []
        for code in pending {
            let descriptor = BadgePresentation(code: code)
            let award = BadgeAwardRecord(
                profileId: profileId,
                stableBadgeId: code.rawValue,
                title: descriptor.title,
                detail: descriptor.explanation,
                symbol: descriptor.symbol,
                source: .system,
                ruleVersion: ruleVersion,
                evidenceIds: evidenceIds(for: code, records: taskRecords)
            )
            context.insert(award)
            inserted.append(award)
        }

        try unlockWishRewards(
            profileId: profileId,
            newlyAwarded: Set(pending.map(\.rawValue)),
            tasks: taskRecords,
            in: context
        )

        if !inserted.isEmpty || context.hasChanges {
            try PersistenceWriter.save(context)
        }
        return inserted
    }

    private static func evidenceIds(for code: BadgeCode, records: [DailyTaskRecord]) -> [UUID] {
        switch code {
        case .firstCheckIn:
            return records
                .filter { $0.status == .completed }
                .sorted { ($0.completedAt ?? .distantFuture) < ($1.completedAt ?? .distantFuture) }
                .prefix(1)
                .map(\.id)
        case .firstChallenge:
            return records.filter { $0.origin == .childChallenge }.prefix(1).map(\.id)
        case .autonomousChallenge:
            return records.filter { $0.origin == .childChallenge && $0.status == .completed }.prefix(1).map(\.id)
        case .firstAchieved:
            let groups = Dictionary(grouping: records, by: \.dayKey)
            return groups.keys.sorted().compactMap { key -> [UUID]? in
                let tasks = groups[key, default: []]
                return StoredDailyProgress(tasks: tasks).isAchieved ? tasks.map(\.id) : nil
            }.first ?? []
        case .flexFiveOfSeven, .comeback:
            return records.filter { $0.status == .completed }.map(\.id)
        }
    }

    private static func unlockWishRewards(
        profileId: UUID,
        newlyAwarded: Set<String>,
        tasks: [DailyTaskRecord],
        in context: ModelContext
    ) throws {
        let existingAwardIds = Set(try context.fetch(FetchDescriptor<BadgeAwardRecord>())
            .filter { $0.profileId == profileId }
            .map(\.stableBadgeId))
            .union(newlyAwarded)
        let achievedThisWeek = currentWeekAchievedDayCount(tasks: tasks)

        for reward in try context.fetch(FetchDescriptor<WishRewardRecord>())
        where reward.profileId == profileId && reward.state == .locked {
            let badgeSatisfied = reward.linkedBadgeId.map(existingAwardIds.contains) ?? false
            let weeklySatisfied = reward.weeklyTarget.map { achievedThisWeek >= $0 } ?? false
            if badgeSatisfied || weeklySatisfied {
                reward.state = .unlocked
                reward.unlockedAt = .now
            }
        }
    }

    private static func currentWeekAchievedDayCount(tasks: [DailyTaskRecord]) -> Int {
        let today = LocalDay(date: .now)
        let calendar = Calendar.guozaiGregorian
        guard
            let todayDate = today.date(calendar: calendar),
            let week = calendar.dateInterval(of: .weekOfYear, for: todayDate)
        else { return 0 }
        let daysElapsed = max(0, calendar.dateComponents([.day], from: week.start, to: todayDate).day ?? 0)
        let validKeys = Set((0...daysElapsed).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start)
                .map { LocalDay(date: $0, calendar: calendar).key }
        })
        return Dictionary(grouping: tasks.filter { validKeys.contains($0.dayKey) }, by: \.dayKey)
            .values
            .count { StoredDailyProgress(tasks: Array($0)).isAchieved }
    }
}

struct BadgePresentation: Identifiable {
    let code: BadgeCode
    var id: BadgeCode { code }

    var title: String {
        switch code {
        case .firstCheckIn: "第一颗星"
        case .firstAchieved: "圆满的一天"
        case .flexFiveOfSeven: "稳稳向前"
        case .comeback: "重新出发"
        case .firstChallenge: "我来挑战"
        case .autonomousChallenge: "自主小达人"
        }
    }

    var condition: String {
        switch code {
        case .firstCheckIn: "完成第一项每日任务"
        case .firstAchieved: "第一次完成当天全部必做任务"
        case .flexFiveOfSeven: "任意 7 天内达成 5 天"
        case .comeback: "暂停之后再次完成今日达成"
        case .firstChallenge: "第一次添加“我的挑战”"
        case .autonomousChallenge: "完成一项自己发起的挑战"
        }
    }

    var explanation: String { "获得条件：\(condition)" }

    var symbol: String {
        switch code {
        case .firstCheckIn: "sparkle"
        case .firstAchieved: "sun.max.fill"
        case .flexFiveOfSeven: "calendar.badge.checkmark"
        case .comeback: "arrow.up.forward.circle.fill"
        case .firstChallenge: "flag.fill"
        case .autonomousChallenge: "figure.arms.open"
        }
    }

    var colorIndex: Int {
        switch code {
        case .firstCheckIn, .firstChallenge: 0
        case .firstAchieved, .flexFiveOfSeven: 1
        case .comeback: 2
        case .autonomousChallenge: 3
        }
    }
}
