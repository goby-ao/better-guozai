import Foundation

/// The raw values are stable serialization identifiers, not visual ordering.
/// Use `journeyOrder` when presenting the stages from seed to fruit.
public enum GrowthGardenStage: Int, CaseIterable, Codable, Hashable, Sendable {
    case seed = 0
    case crackedSeed = 6
    case sprout = 1
    case seedling = 2
    case strongSeedling = 7
    case youngTree = 3
    case leafyTree = 4
    case flourishing = 5
    case fruiting = 8

    public static var journeyOrder: [Self] {
        allCases
    }
}

/// A durable, non-spendable view of achieved days. Every 28 achieved days leaves
/// one completed tree in the garden and starts the next tree from a new seed.
public struct GrowthGardenProgress: Codable, Hashable, Sendable {
    public static let achievedDaysPerTree = 28

    private static let stageMilestones: [(day: Int, stage: GrowthGardenStage)] = [
        (0, .seed),
        (1, .crackedSeed),
        (3, .sprout),
        (6, .seedling),
        (10, .strongSeedling),
        (14, .youngTree),
        (18, .leafyTree),
        (23, .flourishing),
        (28, .fruiting)
    ]

    public let achievedDayCount: Int

    public init(achievedDayCount: Int) {
        self.achievedDayCount = max(0, achievedDayCount)
    }

    public init(tasks: [DailyTaskSnapshot]) {
        let achievedDays = Dictionary(grouping: tasks, by: \.day)
            .values
            .count { DailyProgress(tasks: Array($0)).isAchieved }
        self.init(achievedDayCount: achievedDays)
    }

    public var completedTreeCount: Int {
        achievedDayCount / Self.achievedDaysPerTree
    }

    public var currentTreeDay: Int {
        guard achievedDayCount > 0 else { return 0 }
        return ((achievedDayCount - 1) % Self.achievedDaysPerTree) + 1
    }

    public var currentTreeNumber: Int {
        guard achievedDayCount > 0 else { return 1 }
        return ((achievedDayCount - 1) / Self.achievedDaysPerTree) + 1
    }

    public var completionFraction: Double {
        Double(currentTreeDay) / Double(Self.achievedDaysPerTree)
    }

    public var stage: GrowthGardenStage {
        Self.stageMilestones
            .last { $0.day <= currentTreeDay }?
            .stage ?? .seed
    }

    public var daysUntilNextStage: Int {
        nextMilestone - currentTreeDay
    }

    private var nextMilestone: Int {
        Self.stageMilestones
            .first { $0.day > currentTreeDay }?
            .day ?? Self.achievedDaysPerTree
    }
}
