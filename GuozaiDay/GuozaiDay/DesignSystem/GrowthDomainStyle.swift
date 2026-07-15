import SwiftUI

extension StoredGrowthDomain {
    var themeColor: Color {
        switch self {
        case .learning: GuozaiColor.ocean
        case .reading: GuozaiColor.mango
        case .exercise: GuozaiColor.leaf
        case .selfCare: GuozaiColor.leaf
        case .familyResponsibility: GuozaiColor.coral
        case .exploration: GuozaiColor.oceanDeep
        }
    }

    var softThemeColor: Color {
        switch self {
        case .learning, .exploration: GuozaiColor.oceanSoft
        case .reading: GuozaiColor.mangoSoft
        case .exercise, .selfCare: GuozaiColor.leafSoft
        case .familyResponsibility: GuozaiColor.coralSoft
        }
    }

    var symbol: String {
        switch self {
        case .learning: "pencil.and.scribble"
        case .reading: "book.fill"
        case .exercise: "figure.run"
        case .selfCare: "sparkles"
        case .familyResponsibility: "house.fill"
        case .exploration: "binoculars.fill"
        }
    }
}

extension StoredTaskStatus {
    var accessibilityTitle: String {
        switch self {
        case .pending: "待完成"
        case .completed: "已完成"
        case .skipped: "已跳过"
        }
    }
}
