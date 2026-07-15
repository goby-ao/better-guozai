import SwiftData
import SwiftUI
import UIKit

struct ReminderSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
  @Query(sort: \TaskTemplateRecord.sortOrder) private var templates: [TaskTemplateRecord]

  @AppStorage(ReminderPreferenceKey.morningEnabled) private var morningEnabled = false
  @AppStorage(ReminderPreferenceKey.morningHour) private var morningHour = 7
  @AppStorage(ReminderPreferenceKey.morningMinute) private var morningMinute = 30
  @AppStorage(ReminderPreferenceKey.eveningEnabled) private var eveningEnabled = false
  @AppStorage(ReminderPreferenceKey.eveningHour) private var eveningHour = 20
  @AppStorage(ReminderPreferenceKey.eveningMinute) private var eveningMinute = 30

  @State private var authorization: ReminderAuthorization = .notDetermined
  @State private var schedulingError: String?

  private var activeTemplates: [TaskTemplateRecord] {
    guard let profileID = profiles.first?.id else { return [] }
    return templates.filter {
      $0.profileId == profileID && $0.isActive && $0.deletedAt == nil
    }
  }

  var body: some View {
    Form {
      permissionSection

      Section {
        reminderToggle(
          title: "早晨提醒",
          subtitle: "开启一天的成长计划",
          symbol: "sunrise.fill",
          isOn: $morningEnabled,
          time: timeBinding(hour: $morningHour, minute: $morningMinute)
        )
      } header: {
        Text("每天")
      }

      Section {
        reminderToggle(
          title: "晚间回顾",
          subtitle: "记录心情、星星和骄傲时刻",
          symbol: "moon.stars.fill",
          isOn: $eveningEnabled,
          time: timeBinding(hour: $eveningHour, minute: $eveningMinute)
        )
      }

      Section {
        if activeTemplates.isEmpty {
          ContentUnavailableView(
            "还没有任务模板",
            systemImage: "checklist",
            description: Text("先新增模板，再为重要任务设置单项提醒。")
          )
          .frame(maxWidth: .infinity, minHeight: 150)
        } else {
          ForEach(activeTemplates) { template in
            TemplateReminderRow(
              template: template,
              didChange: {
                Task { await refreshAuthorizationAndSync(requestPermissionIfNeeded: true) }
              },
              onError: { schedulingError = $0 }
            )
          }
        }
      } header: {
        Text("单项提醒")
      } footer: {
        Text("单项提醒会按模板选择的星期出现；任务是否已完成，以当天清单为准。")
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle("提醒设置")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      authorization = await ReminderScheduler.authorization()
      if authorization == .allowed {
        await syncAllReminders()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await refreshAuthorizationAndSync() }
    }
    .onChange(of: morningEnabled) { _, _ in
      Task { await updateDailyReminders(requestPermissionIfNeeded: true) }
    }
    .onChange(of: morningHour) { _, _ in
      Task { await updateDailyReminders() }
    }
    .onChange(of: morningMinute) { _, _ in
      Task { await updateDailyReminders() }
    }
    .onChange(of: eveningEnabled) { _, _ in
      Task { await updateDailyReminders(requestPermissionIfNeeded: true) }
    }
    .onChange(of: eveningHour) { _, _ in
      Task { await updateDailyReminders() }
    }
    .onChange(of: eveningMinute) { _, _ in
      Task { await updateDailyReminders() }
    }
    .alert("提醒设置失败", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { schedulingError = nil }
    } message: {
      Text(schedulingError ?? "请稍后再试。")
    }
  }

  @ViewBuilder
  private var permissionSection: some View {
    Section {
      HStack(alignment: .center, spacing: 14) {
        Image(systemName: permissionSymbol)
          .guozaiScaledSystemFont(size: 23, weight: .semibold)
          .foregroundStyle(permissionTint)
          .frame(width: 52, height: 52)
          .background(permissionTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

        VStack(alignment: .leading, spacing: 4) {
          Text(permissionTitle)
            .guozaiScaledSystemFont(size: 18, weight: .bold, design: .rounded)
            .foregroundStyle(ParentPalette.ink)
          Text(permissionMessage)
            .guozaiScaledSystemFont(size: 15, weight: .medium, design: .rounded)
            .foregroundStyle(ParentPalette.inkSecondary)
        }

        Spacer(minLength: 8)

        permissionAction
      }
      .padding(.vertical, 4)
      .frame(minHeight: 72)
    }
  }

  private func reminderToggle(
    title: String,
    subtitle: String,
    symbol: String,
    isOn: Binding<Bool>,
    time: Binding<Date>
  ) -> some View {
    VStack(spacing: 8) {
      Toggle(isOn: isOn) {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .guozaiScaledSystemFont(size: 18, weight: .bold, design: .rounded)
            Text(subtitle)
              .guozaiScaledSystemFont(size: 15, weight: .medium, design: .rounded)
              .foregroundStyle(ParentPalette.inkSecondary)
          }
        } icon: {
          Image(systemName: symbol)
            .foregroundStyle(ParentPalette.coral)
        }
      }
      .tint(ParentPalette.coral)
      .frame(minHeight: 52)

      if isOn.wrappedValue {
        DatePicker("提醒时间", selection: time, displayedComponents: .hourAndMinute)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
      }
    }
  }

  @ViewBuilder
  private var permissionAction: some View {
    switch authorization {
    case .notDetermined:
      Button("允许") {
        Task {
          authorization = await ReminderScheduler.requestAuthorization()
          if authorization == .allowed {
            await syncAllReminders()
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(ParentPalette.ocean)
      .frame(minHeight: 52)
    case .denied:
      Button("去设置") { openSystemSettings() }
        .buttonStyle(.bordered)
        .tint(ParentPalette.coral)
        .frame(minHeight: 52)
    case .allowed:
      Image(systemName: "checkmark.circle.fill")
        .guozaiScaledSystemFont(size: 24, weight: .semibold)
        .foregroundStyle(ParentPalette.leaf)
        .accessibilityLabel("通知权限已开启")
    }
  }

  private var permissionTitle: String {
    switch authorization {
    case .notDetermined: "开启通知提醒"
    case .denied: "系统通知已关闭"
    case .allowed: "通知提醒已开启"
    }
  }

  private var permissionMessage: String {
    switch authorization {
    case .notDetermined: "允许后，提醒才会按时出现"
    case .denied: "请在系统设置中允许“果仔的一天”通知"
    case .allowed: "早晚和单项提醒会保存在本机"
    }
  }

  private var permissionSymbol: String {
    switch authorization {
    case .notDetermined: "bell.badge.fill"
    case .denied: "bell.slash.fill"
    case .allowed: "bell.and.waves.left.and.right.fill"
    }
  }

  private var permissionTint: Color {
    switch authorization {
    case .notDetermined: ParentPalette.ocean
    case .denied: ParentPalette.coral
    case .allowed: ParentPalette.leaf
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { schedulingError != nil },
      set: { if !$0 { schedulingError = nil } }
    )
  }

  private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
    Binding {
      Calendar.current.date(
        bySettingHour: hour.wrappedValue,
        minute: minute.wrappedValue,
        second: 0,
        of: .now
      ) ?? .now
    } set: { date in
      let components = Calendar.current.dateComponents([.hour, .minute], from: date)
      hour.wrappedValue = components.hour ?? hour.wrappedValue
      minute.wrappedValue = components.minute ?? minute.wrappedValue
    }
  }

  private func refreshAuthorizationAndSync(requestPermissionIfNeeded: Bool = false) async {
    authorization = await ReminderScheduler.authorization()
    if requestPermissionIfNeeded, authorization == .notDetermined {
      authorization = await ReminderScheduler.requestAuthorization()
    }
    if authorization == .allowed {
      await syncAllReminders()
    }
  }

  private func updateDailyReminders(requestPermissionIfNeeded: Bool = false) async {
    if requestPermissionIfNeeded, (morningEnabled || eveningEnabled), authorization == .notDetermined {
      authorization = await ReminderScheduler.requestAuthorization()
    } else {
      authorization = await ReminderScheduler.authorization()
    }

    guard authorization == .allowed else {
      if !morningEnabled {
        ReminderScheduler.remove(identifier: ReminderScheduler.morningIdentifier)
      }
      if !eveningEnabled {
        ReminderScheduler.remove(identifier: ReminderScheduler.eveningIdentifier)
      }
      return
    }

    do {
      try await ReminderScheduler.setMorningReminder(
        enabled: morningEnabled,
        hour: morningHour,
        minute: morningMinute
      )
      try await ReminderScheduler.setEveningReminder(
        enabled: eveningEnabled,
        hour: eveningHour,
        minute: eveningMinute
      )
    } catch {
      schedulingError = error.localizedDescription
    }
  }

  private func syncAllReminders() async {
    await updateDailyReminders()
    do {
      try await ReminderMaintenanceService.syncTemplateReminders(in: modelContext)
    } catch {
      schedulingError = error.localizedDescription
    }
  }

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

private struct TemplateReminderRow: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var template: TaskTemplateRecord
  let didChange: () -> Void
  let onError: (String) -> Void

  private var reminderEnabled: Binding<Bool> {
    Binding {
      template.reminderHour != nil && template.reminderMinute != nil
    } set: { enabled in
      if enabled {
        template.reminderHour = template.reminderHour ?? 17
        template.reminderMinute = template.reminderMinute ?? 0
      } else {
        template.reminderHour = nil
        template.reminderMinute = nil
      }
      template.updatedAt = .now
      do {
        try PersistenceWriter.save(modelContext)
        if !enabled {
          ReminderScheduler.removeTemplateReminder(templateID: template.id)
        }
        didChange()
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

  private var reminderTime: Binding<Date> {
    Binding {
      Calendar.current.date(
        bySettingHour: template.reminderHour ?? 17,
        minute: template.reminderMinute ?? 0,
        second: 0,
        of: .now
      ) ?? .now
    } set: { date in
      let components = Calendar.current.dateComponents([.hour, .minute], from: date)
      template.reminderHour = components.hour ?? 17
      template.reminderMinute = components.minute ?? 0
      template.updatedAt = .now
      do {
        try PersistenceWriter.save(modelContext)
        didChange()
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: reminderEnabled) {
        VStack(alignment: .leading, spacing: 3) {
          Text(template.title)
            .guozaiScaledSystemFont(size: 17, weight: .bold, design: .rounded)
            .foregroundStyle(ParentPalette.ink)
          Text(template.growthDomain.title)
            .guozaiScaledSystemFont(size: 14, weight: .medium, design: .rounded)
            .foregroundStyle(ParentPalette.inkSecondary)
        }
      }
      .tint(ParentPalette.coral)
      .frame(minHeight: 52)

      if reminderEnabled.wrappedValue {
        DatePicker("提醒时间", selection: reminderTime, displayedComponents: .hourAndMinute)
          .guozaiScaledSystemFont(size: 16, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
      }
    }
    .padding(.vertical, 4)
  }
}
