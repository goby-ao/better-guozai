import SwiftData
import SwiftUI

struct HistoryBrowserView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
  @Query(sort: [
    SortDescriptor(\DailyTaskRecord.dayKey, order: .reverse),
    SortDescriptor(\DailyTaskRecord.sortOrder),
  ])
  private var tasks: [DailyTaskRecord]
  @Query private var reflections: [DailyReflectionRecord]
  @State private var showingOneOffEditor = false
  @State private var errorMessage: String?

  private var profileId: UUID? { profiles.first?.id }

  private var profileTasks: [DailyTaskRecord] {
    guard let profileId else { return [] }
    return tasks.filter { $0.profileId == profileId }
  }

  private var summaries: [HistoryDaySummary] {
    Dictionary(grouping: profileTasks, by: \.dayKey)
      .map { dayKey, tasks in
        let profileId = tasks.first?.profileId
        return HistoryDaySummary(
          dayKey: dayKey,
          tasks: tasks,
          reflection: reflections.first(where: {
            $0.dayKey == dayKey && $0.profileId == profileId
          })
        )
      }
      .sorted { $0.dayKey > $1.dayKey }
  }

  var body: some View {
    Group {
      if summaries.isEmpty {
        ContentUnavailableView(
          "还没有历史记录",
          systemImage: "calendar",
          description: Text("完成第一次今日打卡后，这里会出现成长记录。")
        )
      } else {
        List(summaries) { summary in
          NavigationLink {
            HistoryDayDetailView(summary: summary)
          } label: {
            HistoryDayRow(summary: summary)
          }
          .listRowBackground(ParentPalette.card)
          .frame(minHeight: 72)
        }
        .scrollContentBackground(.hidden)
        .background(ParentPalette.paper)
      }
    }
    .navigationTitle("历史记录")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingOneOffEditor = true
        } label: {
          Label("添加单次任务", systemImage: "calendar.badge.plus")
            .frame(minHeight: 52)
        }
        .disabled(profiles.isEmpty)
      }
    }
    .sheet(isPresented: $showingOneOffEditor) {
      NavigationStack {
        ParentOneOffTaskEditor { title, domain, requirement, date in
          addOneOffTask(title: title, domain: domain, requirement: requirement, date: date)
        }
      }
      .presentationDetents([.large])
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

  @MainActor
  private func addOneOffTask(
    title: String,
    domain: StoredGrowthDomain,
    requirement: StoredTaskRequirement,
    date: Date
  ) {
    guard let profile = profiles.first else { return }
    do {
      try DailyPlanStore.addOneOffTask(
        title: title,
        domain: domain,
        requirement: requirement,
        origin: .parentOneOff,
        day: LocalDay(date: date),
        profile: profile,
        in: modelContext
      )
      showingOneOffEditor = false
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct ParentOneOffTaskEditor: View {
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var date = Date.now
  @State private var domain: StoredGrowthDomain = .exploration
  @State private var requirement: StoredTaskRequirement = .optional

  let onSave: (String, StoredGrowthDomain, StoredTaskRequirement, Date) -> Void

  private var cleanedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    Form {
      Section("单次安排") {
        TextField("例如：周六参观自然博物馆", text: $title, axis: .vertical)
          .guozaiScaledSystemFont(size: 19, weight: .semibold, design: .rounded)
          .lineLimit(2...4)
          .frame(minHeight: 64)

        DatePicker("安排日期", selection: $date, displayedComponents: .date)
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)

        Picker("成长领域", selection: $domain) {
          ForEach(StoredGrowthDomain.allCases) { domain in
            Label(domain.title, systemImage: domain.symbol).tag(domain)
          }
        }
        .frame(minHeight: 52)

        Picker("任务类型", selection: $requirement) {
          ForEach(StoredTaskRequirement.allCases) { requirement in
            Text(requirement.title).tag(requirement)
          }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 52)
      }

      Section {
        Text("单次任务只属于选定日期，不会创建长期模板，也不会改动其他日期。")
          .foregroundStyle(ParentPalette.inkSecondary)
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle("添加单次任务")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { dismiss() }.frame(minHeight: 52)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("添加") { onSave(cleanedTitle, domain, requirement, date) }
          .fontWeight(.bold)
          .frame(minHeight: 52)
          .disabled(cleanedTitle.isEmpty)
      }
    }
  }
}

private struct HistoryDayRow: View {
  let summary: HistoryDaySummary

  var body: some View {
    HStack(spacing: 16) {
      VStack(spacing: 2) {
        Text(summary.dayNumber)
          .guozaiScaledSystemFont(size: 26, weight: .bold, design: .rounded)
          .foregroundStyle(summary.isAchieved ? ParentPalette.mango : ParentPalette.ink)
        Text(summary.monthText)
          .guozaiScaledSystemFont(size: 13, weight: .bold, design: .rounded)
          .foregroundStyle(ParentPalette.inkSecondary)
      }
      .frame(width: 54, height: 58)
      .background(
        (summary.isAchieved ? ParentPalette.mango : ParentPalette.ocean).opacity(0.12),
        in: RoundedRectangle(cornerRadius: 16))

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 7) {
          Text(summary.displayDate)
            .guozaiScaledSystemFont(size: 19, weight: .bold, design: .rounded)
            .foregroundStyle(ParentPalette.ink)
          if summary.isAchieved {
            Label("达成", systemImage: "star.fill")
              .guozaiScaledSystemFont(size: 13, weight: .bold, design: .rounded)
              .foregroundStyle(ParentPalette.mango)
          }
        }
        Text(
          "完成 \(summary.completedCount)/\(summary.tasks.count) 项 · 必做 \(summary.requiredCompletedCount)/\(summary.requiredCount) 项"
        )
        .guozaiScaledSystemFont(size: 15, weight: .medium, design: .rounded)
        .foregroundStyle(ParentPalette.inkSecondary)
      }
    }
    .padding(.vertical, 7)
  }
}

struct HistoryDayDetailView: View {
  let summary: HistoryDaySummary

  @State private var correctionRequest: TaskCorrectionRequest?
  @State private var showingReflectionEditor = false

  var body: some View {
    List {
      Section {
        ForEach(summary.tasks.sorted(by: { $0.sortOrder < $1.sortOrder })) { task in
          Button {
            correctionRequest = TaskCorrectionRequest(task: task)
          } label: {
            HStack(spacing: 14) {
              Image(systemName: task.status.historySymbol)
                .guozaiScaledSystemFont(size: 22, weight: .semibold)
                .foregroundStyle(task.status.historyTint)
                .frame(width: 46, height: 46)
                .background(
                  task.status.historyTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

              VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                  .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
                  .foregroundStyle(ParentPalette.ink)
                Text(task.historyDetail)
                  .guozaiScaledSystemFont(size: 14, weight: .medium, design: .rounded)
                  .foregroundStyle(ParentPalette.inkSecondary)
              }

              Spacer()
              Image(systemName: "slider.horizontal.3")
                .foregroundStyle(ParentPalette.inkSecondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .frame(minHeight: 60)
          }
          .buttonStyle(.plain)
          .listRowBackground(ParentPalette.card)
        }
      } header: {
        Text("任务记录")
      } footer: {
        Text("点按任务可修正状态或实际完成量，修改时间会被记录。")
      }

      Section("当日回顾") {
        Button {
          showingReflectionEditor = true
        } label: {
          HStack(spacing: 14) {
            Image(systemName: summary.reflection?.mood?.symbol ?? "quote.bubble")
              .guozaiScaledSystemFont(size: 23, weight: .semibold)
              .foregroundStyle(ParentPalette.ocean)
              .frame(width: 48, height: 48)
              .background(ParentPalette.ocean.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
              Text(summary.reflection == nil ? "补充回顾与鼓励" : "查看或修正回顾")
                .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
                .foregroundStyle(ParentPalette.ink)
              Text(summary.reflection?.parentEncouragement.nonEmpty ?? "给果仔留下一句温暖的鼓励")
                .guozaiScaledSystemFont(size: 14, weight: .medium, design: .rounded)
                .foregroundStyle(ParentPalette.inkSecondary)
                .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(ParentPalette.inkSecondary)
          }
          .frame(minHeight: 64)
        }
        .buttonStyle(.plain)
        .listRowBackground(ParentPalette.card)
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle(summary.displayDate)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $correctionRequest) { request in
      NavigationStack {
        TaskCorrectionView(task: request.task)
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showingReflectionEditor) {
      NavigationStack {
        ReflectionCorrectionView(
          profileId: summary.tasks.first?.profileId,
          dayKey: summary.dayKey,
          reflection: summary.reflection
        )
      }
      .presentationDetents([.large])
    }
  }
}

struct HistoryDaySummary: Identifiable {
  let dayKey: String
  let tasks: [DailyTaskRecord]
  let reflection: DailyReflectionRecord?

  var id: String { dayKey }
  var completedCount: Int { tasks.count(where: { $0.status == .completed }) }
  var requiredCount: Int { tasks.count(where: { $0.requirement == .required }) }
  var requiredCompletedCount: Int {
    tasks.count(where: { $0.requirement == .required && $0.status == .completed })
  }
  var isAchieved: Bool { requiredCount > 0 && requiredCompletedCount == requiredCount }

  private var date: Date? { LocalDay(key: dayKey)?.date() }

  var dayNumber: String {
    date?.formatted(.dateTime.day(.twoDigits)) ?? "--"
  }

  var monthText: String {
    date?.formatted(.dateTime.month(.abbreviated)) ?? ""
  }

  var displayDate: String {
    date?.formatted(.dateTime.year().month().day().weekday(.wide)) ?? dayKey
  }
}

private struct TaskCorrectionRequest: Identifiable {
  let id = UUID()
  let task: DailyTaskRecord
}

extension StoredTaskStatus {
  fileprivate var historyTitle: String {
    switch self {
    case .pending: "未完成"
    case .completed: "已完成"
    case .skipped: "已跳过"
    }
  }

  fileprivate var historySymbol: String {
    switch self {
    case .pending: "circle"
    case .completed: "checkmark.circle.fill"
    case .skipped: "forward.circle.fill"
    }
  }

  fileprivate var historyTint: Color {
    switch self {
    case .pending: ParentPalette.inkSecondary
    case .completed: ParentPalette.leaf
    case .skipped: ParentPalette.mango
    }
  }
}

extension DailyTaskRecord {
  fileprivate var historyDetail: String {
    var parts = [status.historyTitle, requirement.title]
    if let targetValue, let targetUnit {
      let value = actualValue ?? targetValue
      parts.append("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(targetUnit)")
    }
    if correctedAt != nil {
      parts.append("已修正")
    }
    return parts.joined(separator: " · ")
  }
}

extension String {
  fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}
