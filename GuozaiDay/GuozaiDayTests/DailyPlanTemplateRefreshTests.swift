import SwiftData
import XCTest
@testable import GuozaiCore
@testable import GuozaiData

final class DailyPlanTemplateRefreshTests: XCTestCase {
    @MainActor
    func testSyncUpdatesOnlyTodaysPendingTemplateSnapshot() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let yesterday = LocalDay(year: 2026, month: 7, day: 13)
        let today = LocalDay(year: 2026, month: 7, day: 14)
        let profile = ProfileRecord(nickname: "果仔")
        let template = TaskTemplateRecord(
            profileId: profile.id,
            title: "阅读 20 分钟",
            growthDomain: .reading,
            tags: ["阅读"],
            startDayKey: yesterday.key,
            targetValue: 20,
            targetUnit: "分钟"
        )
        context.insert(profile)
        context.insert(template)
        try PersistenceWriter.save(context)
        try DailyPlanStore.ensurePlan(for: yesterday, profile: profile, in: context)
        try DailyPlanStore.ensurePlan(for: today, profile: profile, in: context)

        template.title = "亲子阅读 30 分钟"
        template.growthDomain = .familyResponsibility
        template.tags = ["亲子", "阅读"]
        template.requirement = .optional
        template.targetValue = 30
        template.updatedAt = .now

        try DailyPlanStore.syncCurrentPlanFromTemplates(
            for: today,
            profile: profile,
            in: context
        )

        let tasks = try context.fetch(FetchDescriptor<DailyTaskRecord>())
        let todayTask = try XCTUnwrap(tasks.first { $0.dayKey == today.key })
        let yesterdayTask = try XCTUnwrap(tasks.first { $0.dayKey == yesterday.key })
        XCTAssertEqual(todayTask.title, "亲子阅读 30 分钟")
        XCTAssertEqual(todayTask.growthDomain, .familyResponsibility)
        XCTAssertEqual(todayTask.tags, ["亲子", "阅读"])
        XCTAssertEqual(todayTask.requirement, .optional)
        XCTAssertEqual(todayTask.targetValue, 30)
        XCTAssertEqual(yesterdayTask.title, "阅读 20 分钟")
        XCTAssertEqual(yesterdayTask.targetValue, 20)
    }

    @MainActor
    func testSyncPreservesCompletedTaskSnapshot() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let today = LocalDay(year: 2026, month: 7, day: 14)
        let profile = ProfileRecord(nickname: "果仔")
        let template = TaskTemplateRecord(
            profileId: profile.id,
            title: "旧标题",
            growthDomain: .reading,
            startDayKey: today.key
        )
        context.insert(profile)
        context.insert(template)
        try PersistenceWriter.save(context)
        try DailyPlanStore.ensurePlan(for: today, profile: profile, in: context)

        let task = try XCTUnwrap(context.fetch(FetchDescriptor<DailyTaskRecord>()).first)
        task.status = .completed
        task.completedAt = .now
        template.title = "新标题"
        template.isActive = false

        try DailyPlanStore.syncCurrentPlanFromTemplates(
            for: today,
            profile: profile,
            in: context
        )

        XCTAssertEqual(task.title, "旧标题")
        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyTaskRecord>()), 1)
    }

    @MainActor
    func testSyncRemovesTodaysPendingTaskWhenTemplateIsDisabled() throws {
        let container = try PersistenceModels.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let today = LocalDay(year: 2026, month: 7, day: 14)
        let profile = ProfileRecord(nickname: "果仔")
        let template = TaskTemplateRecord(
            profileId: profile.id,
            title: "阅读 30 分钟",
            growthDomain: .reading,
            startDayKey: today.key
        )
        context.insert(profile)
        context.insert(template)
        try PersistenceWriter.save(context)
        try DailyPlanStore.ensurePlan(for: today, profile: profile, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyTaskRecord>()), 1)

        template.isActive = false
        template.updatedAt = .now
        try DailyPlanStore.syncCurrentPlanFromTemplates(
            for: today,
            profile: profile,
            in: context
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyTaskRecord>()), 0)
    }
}
