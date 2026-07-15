import Foundation

public enum GrowthGardenStage: Int, CaseIterable, Codable, Hashable, Sendable {
    case seed
    case sprout
    case seedling
    case youngTree
    case leafyTree
    case flourishing
}

/// A durable, non-spendable view of achieved days. Every 28 achieved days leaves
/// one completed tree in the garden and starts the next tree from a new seed.
public struct GrowthGardenProgress: Codable, Hashable, Sendable {
    public static let achievedDaysPerTree = 28

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
        switch currentTreeDay {
        case 0:
            .seed
        case 1...2:
            .sprout
        case 3...6:
            .seedling
        case 7...13:
            .youngTree
        case 14...20:
            .leafyTree
        default:
            .flourishing
        }
    }

    public var daysUntilNextStage: Int {
        nextMilestone - currentTreeDay
    }

    private var nextMilestone: Int {
        switch stage {
        case .seed:
            1
        case .sprout:
            3
        case .seedling:
            7
        case .youngTree:
            14
        case .leafyTree:
            21
        case .flourishing:
            Self.achievedDaysPerTree
        }
    }
}
