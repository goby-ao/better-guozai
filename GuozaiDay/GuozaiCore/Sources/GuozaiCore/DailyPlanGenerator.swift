public enum DailyPlanGenerator {
    public static func missingTemplates(
        for day: LocalDay,
        templates: [TaskTemplateSnapshot],
        existingTasks: [DailyTaskSnapshot]
    ) -> [TaskTemplateSnapshot] {
        var seenTemplateIDs = Set<TaskTemplateSnapshot.ID>()

        return templates.filter { template in
            guard seenTemplateIDs.insert(template.id).inserted else { return false }
            guard template.recurrence.applies(to: day) else { return false }

            return !existingTasks.contains { task in
                task.profileID == template.profileID
                    && task.day == day
                    && task.source == .template
                    && task.templateID == template.id
            }
        }
    }
}
