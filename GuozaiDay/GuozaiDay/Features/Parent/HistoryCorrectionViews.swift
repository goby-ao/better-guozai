import SwiftData
import SwiftUI

struct TaskCorrectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let task: DailyTaskRecord

  @State private var status: StoredTaskStatus
  @State private var actualValueText: String
  @State private var skipReason: String
  @State private var errorMessage: String?

  init(task: DailyTaskRecord) {
    self.task = task
    _status = State(initialValue: task.status)
    _actualValueText = State(
      initialValue: task.actualValue.map {
        $0.formatted(.number.precision(.fractionLength(0...1)))
      } ?? "")
    _skipReason = State(initialValue: task.skipReason ?? "")
  }

  var body: some View {
    Form {
      Section {
        Text(task.title)
          .guozaiScaledSystemFont(size: 21, weight: .bold, design: .rounded)
          .foregroundStyle(ParentPalette.ink)
          .frame(minHeight: 52, alignment: .leading)
      }

      Section("完成状态") {
        Picker("状态", selection: $status) {
          ForEach([StoredTaskStatus.pending, .completed, .skipped], id: \.self) { status in
            Text(status.correctionTitle).tag(status)
          }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 52)
      }

      if status == .completed, let targetUnit = task.targetUnit {
        Section("实际完成量") {
          HStack {
            TextField("数量", text: $actualValueText)
              .keyboardType(.decimalPad)
              .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
              .frame(minHeight: 52)
            Text(targetUnit)
              .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
              .foregroundStyle(ParentPalette.inkSecondary)
          }
        }
      }

      if status == .skipped {
        Section("跳过原因") {
          TextField("例如：身体不舒服", text: $skipReason, axis: .vertical)
            .guozaiScaledSystemFont(size: 18, weight: .medium, design: .rounded)
            .lineLimit(2...4)
            .frame(minHeight: 72)
        }
      }

      Section {
        Label("原记录日期：\(task.dayKey)", systemImage: "calendar")
          .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
          .foregroundStyle(ParentPalette.inkSecondary)
          .frame(minHeight: 52)
      } footer: {
        Text("保存后只更新内容与修改时间，不改变记录发生日期。")
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle("修正任务记录")
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
      }
    }
    .alert("暂时没有保存", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private func save() {
    do {
      let now = Date.now
      task.status = status
      task.correctedAt = now
      task.updatedAt = now

      switch status {
      case .pending:
        task.completedAt = nil
        task.skippedAt = nil
        task.skipReason = nil
        task.actualValue = nil
      case .completed:
        task.completedAt = task.completedAt ?? now
        task.skippedAt = nil
        task.skipReason = nil
        let enteredValue = Double(actualValueText.replacingOccurrences(of: ",", with: "."))
        if let enteredValue, enteredValue.isFinite, enteredValue >= 0 {
          task.actualValue = enteredValue
        } else {
          task.actualValue = task.targetValue
        }
      case .skipped:
        task.completedAt = nil
        task.skippedAt = task.skippedAt ?? now
        task.skipReason = skipReason.trimmingCharacters(in: .whitespacesAndNewlines)
        task.actualValue = nil
      }

      _ = try AchievementStore.evaluate(profileId: task.profileId, in: modelContext)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }
}

struct ReflectionCorrectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let profileId: UUID?
  let dayKey: String
  let reflection: DailyReflectionRecord?

  @State private var mood: StoredMood?
  @State private var rating: Int
  @State private var proudMoment: String
  @State private var parentEncouragement: String
  @State private var errorMessage: String?

  init(profileId: UUID?, dayKey: String, reflection: DailyReflectionRecord?) {
    self.profileId = profileId
    self.dayKey = dayKey
    self.reflection = reflection
    _mood = State(initialValue: reflection?.mood)
    _rating = State(initialValue: reflection?.rating ?? 0)
    _proudMoment = State(initialValue: reflection?.proudMoment ?? "")
    _parentEncouragement = State(initialValue: reflection?.parentEncouragement ?? "")
  }

  var body: some View {
    Form {
      Section("当天心情") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(StoredMood.allCases) { item in
              Button {
                mood = item
              } label: {
                VStack(spacing: 7) {
                  Image(systemName: item.symbol)
                    .guozaiScaledSystemFont(size: 24, weight: .semibold)
                  Text(item.title)
                    .guozaiScaledSystemFont(size: 13, weight: .bold, design: .rounded)
                }
                .foregroundStyle(mood == item ? .white : ParentPalette.ink)
                .frame(minWidth: 78, minHeight: 68)
                .background(
                  mood == item ? ParentPalette.ocean : ParentPalette.paper,
                  in: RoundedRectangle(cornerRadius: 16))
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 3)
        }
      }

      Section("今天几颗星") {
        HStack(spacing: 5) {
          ForEach(1...5, id: \.self) { value in
            Button {
              rating = value
            } label: {
              Image(systemName: value <= rating ? "star.fill" : "star")
                .guozaiScaledSystemFont(size: 26, weight: .semibold)
                .foregroundStyle(ParentPalette.mango)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(value) 颗星")
          }
        }
      }

      Section("果仔最骄傲的事") {
        TextField("记录今天的小进步", text: $proudMoment, axis: .vertical)
          .guozaiScaledSystemFont(size: 18, weight: .medium, design: .rounded)
          .lineLimit(2...5)
          .frame(minHeight: 72)
      }

      Section("家长鼓励") {
        TextField("写一句具体、温暖的鼓励", text: $parentEncouragement, axis: .vertical)
          .guozaiScaledSystemFont(size: 18, weight: .medium, design: .rounded)
          .lineLimit(2...5)
          .frame(minHeight: 84)
      }
    }
    .scrollContentBackground(.hidden)
    .background(ParentPalette.paper)
    .navigationTitle("当日回顾")
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
          .disabled(profileId == nil)
      }
    }
    .alert("暂时没有保存", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private func save() {
    guard let profileId else { return }
    do {
      let now = Date.now
      let target = reflection ?? DailyReflectionRecord(profileId: profileId, dayKey: dayKey)
      if reflection == nil {
        modelContext.insert(target)
      }
      target.mood = mood
      target.rating = rating == 0 ? nil : rating
      target.proudMoment = proudMoment.trimmingCharacters(in: .whitespacesAndNewlines)
      target.parentEncouragement = parentEncouragement.trimmingCharacters(in: .whitespacesAndNewlines)
      target.updatedAt = now
      target.correctedAt = now
      try PersistenceWriter.save(modelContext)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }
}

extension StoredTaskStatus {
  fileprivate var correctionTitle: String {
    switch self {
    case .pending: "未完成"
    case .completed: "已完成"
    case .skipped: "已跳过"
    }
  }
}
