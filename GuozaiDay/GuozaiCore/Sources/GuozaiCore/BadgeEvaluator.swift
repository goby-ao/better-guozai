import Foundation

public enum BadgeCode: String, Codable, CaseIterable, Sendable {
    case firstCheckIn = "first-checkin"
    case firstAchieved = "first-achieved"
    case flexFiveOfSeven = "flex-5-of-7"
    case comeback
    case firstChallenge = "first-challenge"
    case autonomousChallenge = "autonomous-challenge"
}

public enum BadgeEvaluator {
    public static func pendingAwards(
        for profileID: UUID,
        tasks: [DailyTaskSnapshot],
        alreadyAwarded: Set<BadgeCode>
    ) -> [BadgeCode] {
        let profileTasks = tasks.filter { $0.profileID == profileID }
        var qualified = Set<BadgeCode>()

        if profileTasks.contains(where: { $0.state == .completed }) {
            qualified.insert(.firstCheckIn)
        }
        if profileTasks.contains(where: {
            $0.source == .challenge && $0.state == .completed
        }) {
            qualified.insert(.autonomousChallenge)
        }
        if profileTasks.contains(where: { $0.source == .challenge }) {
            qualified.insert(.firstChallenge)
        }

        let tasksByDay = Dictionary(grouping: profileTasks, by: \.day)
        let achievedDays = tasksByDay.compactMap { day, tasks in
            DailyProgress(tasks: tasks).isAchieved ? day : nil
        }.sorted()
        if !achievedDays.isEmpty {
            qualified.insert(.firstAchieved)
        }
        if hasFiveDaysInSeven(achievedDays) {
            qualified.insert(.flexFiveOfSeven)
        }
        if hasInterruptedAchievement(in: achievedDays) {
            qualified.insert(.comeback)
        }

        return BadgeCode.allCases.filter {
            qualified.contains($0) && !alreadyAwarded.contains($0)
        }
    }

    private static func hasFiveDaysInSeven(_ days: [LocalDay]) -> Bool {
        var windowStart = 0
        for windowEnd in days.indices {
            while windowStart < windowEnd,
                  distance(from: days[windowStart], to: days[windowEnd]) > 6 {
                windowStart += 1
            }
            if windowEnd - windowStart + 1 >= 5 {
                return true
            }
        }
        return false
    }

    private static func hasInterruptedAchievement(in days: [LocalDay]) -> Bool {
        zip(days, days.dropFirst()).contains { previous, current in
            distance(from: previous, to: current) > 1
        }
    }

    private static func distance(from start: LocalDay, to end: LocalDay) -> Int {
        let calendar = Calendar.guozaiStableGregorian
        guard
            let startDate = start.date(calendar: calendar),
            let endDate = end.date(calendar: calendar)
        else {
            return .max
        }
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? .max
    }
}
