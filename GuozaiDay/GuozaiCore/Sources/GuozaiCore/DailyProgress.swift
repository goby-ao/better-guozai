public struct DailyProgress: Codable, Hashable, Sendable {
    public let taskCount: Int
    public let completedCount: Int
    public let skippedCount: Int
    public let requiredCount: Int
    public let completedRequiredCount: Int

    public var isAchieved: Bool {
        requiredCount > 0 && completedRequiredCount == requiredCount
    }

    public init(tasks: [DailyTaskSnapshot]) {
        taskCount = tasks.count
        completedCount = tasks.count { $0.state == .completed }
        skippedCount = tasks.count { $0.state == .skipped }

        let requiredTasks = tasks.filter { $0.requirement == .required }
        requiredCount = requiredTasks.count
        completedRequiredCount = requiredTasks.count { $0.state == .completed }
    }
}
