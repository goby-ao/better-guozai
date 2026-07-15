import SwiftData
import SwiftUI

struct TemplateManagerView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \TaskTemplateRecord.sortOrder) private var templates: [TaskTemplateRecord]
  @Query private var profiles: [ProfileRecord]

  @State private var editorRequest: TemplateEditorRequest?
  @State private var pendingDeletion: TaskTemplateRecord?
  @State private var errorMessage: String?

  private var visibleTemplates: [TaskTemplateRecord] {
    guard let profileID = profiles.first?.id else { return [] }
    return templates.filter { $0.profileId == profileID && $0.deletedAt == nil }
  }

  private var archivedCount: Int {
    guard let profileID = profiles.first?.id else { return 0 }
    return templates.count(where: { $0.profileId == profileID && $0.deletedAt != nil })
  }

  var body: some View {
    Group {
      if visibleTemplates.isEmpty {
        ContentUnavailableView {
          Label("还没有任务模板", systemImage: "checklist")
        } description: {
          Text("新增一个模板，之后会按重复规则出现在每天的计划中。")
        } actions: {
          addButton
        }
      } else {
        List {
          Section {
            ForEach(visibleTemplates) { template in
              TemplateRow(
                template: template,
                edit: {
                  editorRequest = TemplateEditorRequest(
                    profileId: template.profileId,
                    template: template
                  )
                },
                onError: { errorMessage = $0 }
              )
              .listRowBackground(ParentPalette.card)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  pendingDeletion = template
                } label: {
                  Label("归档", systemImage: "archivebox")
                }
              }
            }
          } header: {
            Text("正在使用 · \(visibleTemplates.filter(\.isActive).count) 个")
          } footer: {
            if archivedCount > 0 {
              Text("另有 \(archivedCount) 个已归档模板。归档不会删除过去的打卡记录。")
            }
          }
        }
        .scrollContentBackground(.hidden)
        .background(ParentPalette.paper)
      }
    }
    .navigationTitle("任务模板")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        addButton
      }
    }
    .sheet(item: $editorRequest) { request in
      NavigationStack {
        TemplateEditorView(profileId: request.profileId, template: request.template)
      }
      .presentationDetents([.large])
    }
    .confirmationDialog(
      "归档“\(pendingDeletion?.title ?? "这个模板")”？",
      isPresented: Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("归档模板", role: .destructive) {
        guard let template = pendingDeletion else { return }
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
        } catch {
          errorMessage = error.localizedDescription
        }
        pendingDeletion = nil
      }
      Button("取消", role: .cancel) {
        pendingDeletion = nil
      }
    } message: {
      Text("只停止以后生成任务，不会影响已经发生的历史记录。")
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

  private var addButton: some View {
    Button {
      guard let profileId = profiles.first?.id else { return }
      editorRequest = TemplateEditorRequest(profileId: profileId, template: nil)
    } label: {
      Label("新增模板", systemImage: "plus")
        .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
        .frame(minHeight: 52)
    }
    .disabled(profiles.isEmpty)
  }
}

private struct TemplateRow: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var template: TaskTemplateRecord
  let edit: () -> Void
  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: edit) {
        HStack(spacing: 14) {
          Image(systemName: template.growthDomain.symbol)
            .guozaiScaledSystemFont(size: 23, weight: .semibold)
            .foregroundStyle(template.growthDomain.tint)
            .frame(width: 48, height: 48)
            .background(
              template.growthDomain.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              Text(template.title)
                .guozaiScaledSystemFont(size: 19, weight: .semibold, design: .rounded)
                .foregroundStyle(ParentPalette.ink)
                .strikethrough(!template.isActive, color: ParentPalette.inkSecondary)
              Text(template.requirement.title)
                .guozaiScaledSystemFont(size: 13, weight: .bold, design: .rounded)
                .foregroundStyle(
                  template.requirement == .required ? ParentPalette.coral : ParentPalette.ocean
                )
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                  (template.requirement == .required ? ParentPalette.coral : ParentPalette.ocean)
                    .opacity(0.12),
                  in: Capsule()
                )
            }

            Text(template.summaryText)
              .guozaiScaledSystemFont(size: 15, weight: .medium, design: .rounded)
              .foregroundStyle(ParentPalette.inkSecondary)
          }

          Spacer(minLength: 4)

          Image(systemName: "chevron.right")
            .guozaiScaledSystemFont(size: 14, weight: .bold)
            .foregroundStyle(ParentPalette.inkSecondary.opacity(0.65))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
      }
      .buttonStyle(.plain)
      .accessibilityHint("编辑模板")

      Toggle("启用", isOn: $template.isActive)
        .labelsHidden()
        .tint(ParentPalette.leaf)
        .frame(minWidth: 52, minHeight: 52)
        .onChange(of: template.isActive) { _, isActive in
          template.updatedAt = .now
          do {
            try DailyPlanStore.syncCurrentPlanFromTemplates(
              for: LocalDay(date: .now),
              profileID: template.profileId,
              in: modelContext
            )
            if isActive {
              scheduleReminderIfNeeded()
            } else {
              ReminderScheduler.removeTemplateReminder(templateID: template.id)
            }
          } catch {
            onError(error.localizedDescription)
          }
        }
    }
  }

  private func scheduleReminderIfNeeded() {
    guard template.reminderHour != nil, template.reminderMinute != nil else { return }
    Task {
      do {
        try await ReminderMaintenanceService.syncTemplateReminders(in: modelContext)
      } catch {
        onError(error.localizedDescription)
      }
    }
  }
}

private struct TemplateEditorRequest: Identifiable {
  let id = UUID()
  let profileId: UUID
  let template: TaskTemplateRecord?
}

extension StoredGrowthDomain {
  var tint: Color {
    switch self {
    case .learning: ParentPalette.ocean
    case .reading: Color(red: 0.55, green: 0.38, blue: 0.67)
    case .exercise: ParentPalette.coral
    case .selfCare: ParentPalette.mango
    case .familyResponsibility: ParentPalette.leaf
    case .exploration: Color(red: 0.20, green: 0.56, blue: 0.53)
    }
  }
}

extension RecurrenceRule.Kind {
  var parentTitle: String {
    switch self {
    case .daily: "每天"
    case .weekdays: "工作日"
    case .weekends: "周末"
    case .custom: "自定义星期"
    }
  }
}

extension TaskTemplateRecord {
  fileprivate var summaryText: String {
    var parts = [growthDomain.title, recurrenceKind.parentTitle]
    if let targetValue, let targetUnit, !targetUnit.isEmpty {
      parts.append(
        "\(targetValue.formatted(.number.precision(.fractionLength(0...1)))) \(targetUnit)")
    }
    if !isActive {
      parts.append("已停用")
    }
    return parts.joined(separator: " · ")
  }
}
