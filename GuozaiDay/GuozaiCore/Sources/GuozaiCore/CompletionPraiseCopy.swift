import Foundation

public struct CompletionPraise: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public enum CompletionPraiseCopy {
    public static func make(
        for task: DailyTaskSnapshot,
        isDayAchieved: Bool
    ) -> CompletionPraise {
        if isDayAchieved {
            return CompletionPraise(
                title: "今天的计划完成了",
                message: "你一项一项完成了今天的计划，小树也长大了一步。"
            )
        }

        if task.source == .challenge {
            return CompletionPraise(
                title: "自己选的挑战，做到了",
                message: "这是你自己选的目标，你认真把它完成了。"
            )
        }

        switch task.growthArea {
        case .learning:
            return CompletionPraise(
                title: "一步一步，完成了",
                message: "你按计划完成了今天的练习，这份认真值得记住。"
            )
        case .reading:
            return CompletionPraise(
                title: "专心阅读，做到了",
                message: quantityMessage(
                    for: task,
                    action: "专心读完了",
                    fallback: "你留出时间认真阅读，耐心又长大了一点。",
                    ending: "耐心又长大了一点。"
                )
            )
        case .exercise:
            return CompletionPraise(
                title: "认真运动，做到了",
                message: quantityMessage(
                    for: task,
                    action: "认真活动了",
                    fallback: "你认真活动了身体，又积攒了一点力量。",
                    ending: "身体又积攒了一点力量。"
                )
            )
        case .selfCare:
            return CompletionPraise(
                title: "自己的事，照顾好了",
                message: "你认真把自己的事情做好了，今天更独立了一点。"
            )
        case .familyResponsibility:
            return CompletionPraise(
                title: "为家里出了一份力",
                message: "你主动为家里出了一份力，这份行动很温暖。"
            )
        case .interestExploration:
            return CompletionPraise(
                title: "好奇心有了新发现",
                message: "你认真完成了一次新探索，又发现了更大的世界。"
            )
        }
    }

    private static func quantityMessage(
        for task: DailyTaskSnapshot,
        action: String,
        fallback: String,
        ending: String
    ) -> String {
        guard
            let quantity = task.actualQuantity ?? task.target?.amount,
            let unit = task.target?.unit,
            !unit.isEmpty
        else { return fallback }

        let value = NSDecimalNumber(decimal: quantity).stringValue
        return "你\(action) \(value) \(unit)，\(ending)"
    }
}
