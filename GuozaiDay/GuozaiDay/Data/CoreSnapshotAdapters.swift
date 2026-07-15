import Foundation
#if SWIFT_PACKAGE
import GuozaiCore
#endif

extension StoredGrowthDomain {
    var coreValue: GrowthArea {
        switch self {
        case .learning: .learning
        case .reading: .reading
        case .exercise: .exercise
        case .selfCare: .selfCare
        case .familyResponsibility: .familyResponsibility
        case .exploration: .interestExploration
        }
    }
}

extension StoredTaskRequirement {
    var coreValue: TaskRequirement { self == .required ? .required : .optional }
}

extension StoredTaskOrigin {
    var coreValue: DailyTaskSource {
        switch self {
        case .template: .template
        case .parentOneOff: .parentOneOff
        case .childChallenge: .challenge
        }
    }
}

extension StoredTaskStatus {
    var coreValue: DailyTaskState {
        switch self {
        case .pending: .pending
        case .completed: .completed
        case .skipped: .skipped
        }
    }
}

extension TaskTemplateRecord {
    var coreSnapshot: TaskTemplateSnapshot? {
        guard let start = LocalDay(key: startDayKey) else { return nil }
        let pauses: [RecurrenceRule.Pause]
        if let pauseStartDayKey, let pauseStart = LocalDay(key: pauseStartDayKey) {
            let pauseEnd = pauseEndDayKey.flatMap { LocalDay(key: $0) }
                ?? LocalDay(year: 9999, month: 12, day: 31)
            pauses = [.init(start: pauseStart, end: pauseEnd)]
        } else {
            pauses = []
        }
        let target = targetValue.flatMap { value in
            targetUnit.map { QuantityTarget(amount: Decimal(value), unit: $0) }
        }
        return TaskTemplateSnapshot(
            id: id,
            profileID: profileId,
            title: title,
            growthArea: growthDomain.coreValue,
            tags: tags,
            requirement: requirement.coreValue,
            recurrence: RecurrenceRule(
                kind: recurrenceKind,
                start: start,
                end: endDayKey.flatMap { LocalDay(key: $0) },
                weekdays: weekdays,
                pauses: pauses
            ),
            target: target,
            sortOrder: sortOrder,
            isActive: isActive,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}

extension DailyTaskRecord {
    var coreSnapshot: DailyTaskSnapshot? {
        guard let day = LocalDay(key: dayKey) else { return nil }
        let target = targetValue.flatMap { value in
            targetUnit.map { QuantityTarget(amount: Decimal(value), unit: $0) }
        }
        return DailyTaskSnapshot(
            id: id,
            profileID: profileId,
            day: day,
            title: title,
            growthArea: growthDomain.coreValue,
            tags: tags,
            requirement: requirement.coreValue,
            source: origin.coreValue,
            templateID: templateId,
            target: target,
            state: status.coreValue,
            actualQuantity: actualValue.map { Decimal($0) },
            completedAt: completedAt,
            skippedAt: skippedAt,
            skipReason: skipReason,
            correctedAt: correctedAt,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
