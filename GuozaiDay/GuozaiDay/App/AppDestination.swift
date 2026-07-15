import SwiftUI

enum AppDestination: String, CaseIterable, Hashable, Identifiable {
    case today
    case growth
    case badges
    case parent

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今日"
        case .growth: "成长"
        case .badges: "勋章"
        case .parent: "家长中心"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "checklist"
        case .growth: "sparkles"
        case .badges: "medal"
        case .parent: "person.2"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .today: "checkmark.circle.fill"
        case .growth: "sparkles"
        case .badges: "medal.fill"
        case .parent: "person.2.fill"
        }
    }

    @MainActor @ViewBuilder
    var rootView: some View {
        switch self {
        case .today:
            TodayView()
        case .growth:
            GrowthView()
        case .badges:
            BadgesView()
        case .parent:
            ParentHomeView()
        }
    }
}
