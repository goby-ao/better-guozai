import SwiftData
import SwiftUI

struct TemplateEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let profileId: UUID
  let template: TaskTemplateRecord?

  @State private var title: String
  @State private var domain: StoredGrowthDomain
  @State private var tagsText: String
  @State private var requirement: StoredTaskRequirement
  @State private var recurrenceKind: RecurrenceRule.Kind
  @State private var weekdays: Set<Int>
  @State private var startDate: Date
  @State private var hasEndDate: Bool
  @State private var endDate: Date
  @State private var hasPause: Bool
  @State private var pauseStartDate: Date
  @State private var pauseEndDate: Date
  @State private var hasQuantityGoal: Bool
  @State private var targetValueText: String
  @State private var targetUnit: String
  @State private var hasReminder: Bool
  @State private var reminderTime: Date
  @State private var isActive: Bool
  @State private var showingArchiveConfirmation = false
  @State private var errorMessage: String?

  private let weekdayChoices: [(value: Int, title: String)] = [
    (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日"),
  ]

  init(profileId: UUID, template: TaskTemplateRecord?) {
    func storedDate(for dayKey: String?) -> Date? {
      guard let dayKey else { return nil }
      return LocalDay(key: dayKey)?.date()
    }

    self.profileId = profileId
    self.template = template
    _title = State(initialValue: template?.title ?? "")
    _domain = State(initialValue: template?.growthDomain ?? .learning)
    _tagsText = State(initialValue: template?.tags.joined(separator: "、") ?? "")
    _requirement = State(initialValue: template?.requirement ?? .required)
    _recurrenceKind = State(initialValue: template?.recurrenceKind ?? .daily)
    _weekdays = State(initialValue: template?.weekdays ?? [2, 3, 4, 5, 6])
    let today = Date.now
    let initialStart = storedDate(for: template?.startDayKey) ?? today
    _startDate = State(initialValue: initialStart)
    _hasEndDate = State(initialValue: template?.endDayKey != nil)
    _endDate = State(
      initialValue: storedDate(for: template?.endDayKey)
        ?? Calendar.current.date(byAdding: .month, value: 3, to: initialStart)
        ?? initialStart
    )
    let initialPauseStart = storedDate(for: template?.pauseStartDayKey)
      ?? Calendar.current.date(byAdding: .day, value: 1, to: today)
      ?? today
    _hasPause = State(initialValue: template?.pauseStartDayKey != nil)
    _pauseStartDate = State(initialValue: initialPauseStart)
    _pauseEndDate = State(
      initialValue: storedDate(for: template?.pauseEndDayKey)
        ?? Calendar.current.date(byAdding: .day, value: 7, to: initialPauseStart)
        ?? initialPauseStart
    )
    _hasQuantityGoal = State(initialValue: template?.targetValue != nil)
    _targetValueText = State(
      initialValue: template?.targetValue.map {
        $0.formatted(.number.precision(.fractionLength(0...1)))
      } ?? "")
    _targetUnit = State(initialValue: template?.targetUnit ?? "分钟")
    _hasReminder = State(
      initialValue: template?.reminderHour != nil && template?.reminderMinute != nil
    )
    _reminderTime = State(
      initialValue: Calendar.current.date(
        bySettingHour: template?.reminderHour ?? 17,
        minute: template?.reminderMinute ?? 0,
        second: 0,
        of: .now
      ) ?? .now
    )
    _isActive = State(initialValue: template?.isActive ?? true)
  }

  var body: some View {
    Form {
      Section("任务内容") {
        TextField("例如：阅读 30 分钟", text: $title, axis: .vertical)
          .guozaiScaledSystemFont(size: 19, weight: .semibold, design: .rounded)
          .lineLimit(2...4)
          .frame(minHeight: 52)

        Picker("成长领域", selection: $domain) {
          ForEach(StoredGrowthDomain.allCases) { domain in
            Label(domain.title, systemImage: domain.symbol)
              .tag(domain)
          }
        }
        .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
        .frame(minHeight: 52)

        Picker("任务类型", selection: $requirement) {
          ForEach(StoredTaskRequirement.allCases) { requirement in
            Text(requirement.title).tag(requirement)
          }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 52)

        TextField("标签，例如：数学、英语", text: $tagsText)
          .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
          .frame(minHeight: 52)
      }

      Section("重复计划") {
        Picker("重复", selection: $recurrenceKind) {
          ForEach(RecurrenceRule.Kind.allCases, id: \.self) { kind in
            Text(kind.parentTitle).tag(kind)
          }
        }
        .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
        .frame(minHeight: 52)

        if recurrenceKind == .custom {
          VStack(alignment: .leading, spacing: 12) {
            Text("选择星期")
              .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
            HStack(spacing: 8) {
              ForEach(weekdayChoices, id: \.value) { choice in
                Button {
                  toggleWeekday(choice.value)
                } label: {
                  Text(choice.title)
                    .guozaiScaledSystemFont(size: 16, weight: .bold, design: .rounded)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(weekdays.contains(choice.value) ? .white : ParentPalette.ink)
                    .background(
                      weekdays.contains(choice.value) ? ParentPalette.ocean : ParentPalette.paper,
                      in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("星期\(choice.title)")
                .accessibilityValue(weekdays.contains(choice.value) ? "已选择" : "未选择")
              }
            }
          }
          .padding(.vertical, 6)
        }

        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)

        Toggle("设置结束日期", isOn: $hasEndDate)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .tint(ParentPalette.ocean)
          .frame(minHeight: 52)

        if hasEndDate {
          DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
            .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
            .frame(minHeight: 52)
        }
      }

      Section {
        Toggle("临时暂停一段时间", isOn: $hasPause)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .tint(ParentPalette.mango)
          .frame(minHeight: 52)

        if hasPause {
          DatePicker("暂停开始", selection: $pauseStartDate, displayedComponents: .date)
            .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
            .frame(minHeight: 52)
          DatePicker(
            "恢复前一天",
            selection: $pauseEndDate,
            in: pauseStartDate...,
            displayedComponents: .date
          )
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
        }
      } header: {
        Text("暂停安排")
      } footer: {
        Text("暂停期间不会生成新任务，已有历史记录不会改变。")
      }

      Section {
        Toggle("设置量化目标", isOn: $hasQuantityGoal)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .tint(ParentPalette.leaf)
          .frame(minHeight: 52)

        if hasQuantityGoal {
          HStack(spacing: 12) {
            TextField("数量", text: $targetValueText)
              .keyboardType(.decimalPad)
              .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
              .frame(minHeight: 52)

            TextField("单位", text: $targetUnit)
              .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
              .frame(minHeight: 52)
          }
        }
      } header: {
        Text("完成目标")
      } footer: {
        Text("量化目标可用于记录阅读分钟、运动时长或练习页数。")
      }

      Section {
        Toggle("为这项任务设置提醒", isOn: $hasReminder)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .tint(ParentPalette.coral)
          .frame(minHeight: 52)

        if hasReminder {
          DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
            .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
            .frame(minHeight: 52)
        }
      } header: {
        Text("单项提醒")
      } footer: {
        Text("通知权限关闭时，可在家长区的“提醒设置”中重新开启。")
      }

      Section("状态") {
        Toggle("启用模板", isOn: $isActive)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .tint(ParentPalette.leaf)
          .frame(minHeight: 52)
      }

      if template != nil {
        Section {
          Button(role: .destructive) {
            showingArchiveConfirmation = true
          } label: {
            Label("归档这个模板", systemImage: "archivebox")
              .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
              .frame(maxWidth: .infinity, minHeight: 52)
          }
        } footer: {
          Text("归档只影响未来计划，不会删除过去的打卡数据。")
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle(template == nil ? "新增模板" : "编辑模板")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { dismiss() }
          .frame(minHeight: 52)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("保存", action: save)
          .fontWeight(.bold)
          .frame(minHeight: 52)
          .disabled(!canSave)
      }
    }
    .confirmationDialog("确定归档这个模板？", isPresented: $showingArchiveConfirmation) {
      Button("归档模板", role: .destructive, action: archive)
      Button("取消", role: .cancel) {}
    } message: {
      Text("已经生成的历史任务会完整保留。")
    }
    .alert("暂时没有保存", isPresented: Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private var canSave: Bool {
    let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let hasValidCustomDays = recurrenceKind != .custom || !weekdays.isEmpty
    let hasValidTarget =
      !hasQuantityGoal
      || (parsedTargetValue != nil
        && !targetUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    let hasValidEnd = !hasEndDate || endDate >= startDate
    let hasValidPause = !hasPause || pauseEndDate >= pauseStartDate
    return hasTitle && hasValidCustomDays && hasValidTarget && hasValidEnd && hasValidPause
  }

  private func toggleWeekday(_ value: Int) {
    if weekdays.contains(value) {
      weekdays.remove(value)
    } else {
      weekdays.insert(value)
    }
  }

  private func save() {
    guard canSave else { return }

    do {
      let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      let cleanedUnit = targetUnit.trimmingCharacters(in: .whitespacesAndNewlines)
      let cleanedTags = parsedTags
      let quantity = hasQuantityGoal ? parsedTargetValue : nil
      let reminderComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
      let reminderHour = hasReminder ? reminderComponents.hour : nil
      let reminderMinute = hasReminder ? reminderComponents.minute : nil
      let savedTemplate: TaskTemplateRecord

      if let template {
        template.title = cleanedTitle
        template.growthDomain = domain
        template.tags = cleanedTags
        template.requirement = requirement
        template.recurrenceKind = recurrenceKind
        template.weekdays = recurrenceKind == .custom ? weekdays : []
        template.startDayKey = LocalDay(date: startDate).key
        template.endDayKey = hasEndDate ? LocalDay(date: endDate).key : nil
        template.pauseStartDayKey = hasPause ? LocalDay(date: pauseStartDate).key : nil
        template.pauseEndDayKey = hasPause ? LocalDay(date: pauseEndDate).key : nil
        template.targetValue = quantity
        template.targetUnit = hasQuantityGoal ? cleanedUnit : nil
        template.reminderHour = reminderHour
        template.reminderMinute = reminderMinute
        template.isActive = isActive
        template.updatedAt = .now
        savedTemplate = template
      } else {
        let descriptor = FetchDescriptor<TaskTemplateRecord>()
        let nextSortOrder = try modelContext.fetch(descriptor)
          .map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let newTemplate = TaskTemplateRecord(
          profileId: profileId,
          title: cleanedTitle,
          growthDomain: domain,
          tags: cleanedTags,
          requirement: requirement,
          recurrenceKind: recurrenceKind,
          startDayKey: LocalDay(date: startDate).key,
          endDayKey: hasEndDate ? LocalDay(date: endDate).key : nil,
          weekdays: recurrenceKind == .custom ? weekdays : [],
          pauseStartDayKey: hasPause ? LocalDay(date: pauseStartDate).key : nil,
          pauseEndDayKey: hasPause ? LocalDay(date: pauseEndDate).key : nil,
          targetValue: quantity,
          targetUnit: hasQuantityGoal ? cleanedUnit : nil,
          reminderHour: reminderHour,
          reminderMinute: reminderMinute,
          sortOrder: nextSortOrder,
          isActive: isActive
        )
        modelContext.insert(newTemplate)
        savedTemplate = newTemplate
      }

      try insertNewTags(cleanedTags)
      if let profile = try modelContext.fetch(FetchDescriptor<ProfileRecord>())
        .first(where: { $0.id == profileId })
      {
        try DailyPlanStore.syncCurrentPlanFromTemplates(
          for: LocalDay(date: .now),
          profile: profile,
          in: modelContext
        )
      } else {
        try PersistenceWriter.save(modelContext)
      }
      syncReminder(for: savedTemplate)
      dismiss()
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }

  private func archive() {
    guard let template else { return }
    do {
      template.isActive = false
      template.deletedAt = .now
      template.updatedAt = .now
      try DailyPlanStore.syncCurrentPlanFromTemplates(
        for: LocalDay(date: .now),
        profileID: template.profileId,
        in: modelContext
      )
      ReminderScheduler.removeTemplateReminder(templateID: template.id)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func syncReminder(for template: TaskTemplateRecord) {
    guard hasReminder else {
      ReminderScheduler.removeTemplateReminder(templateID: template.id)
      return
    }

    Task {
      var authorization = await ReminderScheduler.authorization()
      if authorization == .notDetermined {
        authorization = await ReminderScheduler.requestAuthorization()
      }
      guard authorization == .allowed else { return }

      do {
        try await ReminderMaintenanceService.syncTemplateReminders(in: modelContext)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private var parsedTags: [String] {
    let separators = CharacterSet(charactersIn: ",，、\n")
    var seen = Set<String>()
    return tagsText
      .components(separatedBy: separators)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  private var parsedTargetValue: Double? {
    guard
      let value = Double(targetValueText.replacingOccurrences(of: ",", with: ".")),
      value.isFinite,
      value > 0
    else { return nil }
    return value
  }

  private func insertNewTags(_ names: [String]) throws {
    let existing = try modelContext.fetch(FetchDescriptor<TagRecord>())
    let existingNames = Set(existing.filter { $0.profileId == profileId }.map(\.name))
    for name in names where !existingNames.contains(name) {
      modelContext.insert(TagRecord(profileId: profileId, name: name))
    }
  }
}
