public enum WishUnlockPolicy {
    /// Badge-linked wishes keep their original behavior. Weekly wishes only
    /// unlock when the child has actively selected that wish.
    public static func isSatisfied(
        linkedBadgeSatisfied: Bool,
        weeklyTarget: Int?,
        isSelectedWeeklyWish: Bool,
        achievedDayCount: Int
    ) -> Bool {
        if linkedBadgeSatisfied {
            return true
        }

        guard
            isSelectedWeeklyWish,
            let weeklyTarget,
            weeklyTarget > 0
        else { return false }

        return achievedDayCount >= weeklyTarget
    }
}
