import SwiftData
import SwiftUI

struct ProfileSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]

  @State private var nickname = "果仔"
  @State private var grade = ""
  @State private var avatarSymbol = "face.smiling.fill"
  @State private var loadedProfileID: UUID?
  @State private var savedNotice = false
  @State private var errorMessage: String?

  private let avatarSymbols = [
    "face.smiling.fill", "sun.max.fill", "star.fill", "leaf.fill",
    "book.fill", "figure.run.circle.fill", "paintpalette.fill", "music.note"
  ]

  var body: some View {
    Form {
      Section {
        HStack(spacing: GuozaiSpacing.large) {
          ZStack {
            Circle().fill(GuozaiColor.mangoSoft)
            Image(systemName: avatarSymbol)
              .guozaiScaledSystemFont(size: 36, weight: .bold)
              .foregroundStyle(GuozaiColor.oceanDeep)
          }
          .frame(width: 86, height: 86)

          VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
            Text(nickname.isEmpty ? "果仔" : nickname)
              .guozaiTextStyle(.sectionTitle)
              .foregroundStyle(GuozaiColor.ink)
            Text(grade.isEmpty ? "一起记录每天的成长" : grade)
              .guozaiTextStyle(.body)
              .foregroundStyle(GuozaiColor.inkMuted)
          }
        }
        .frame(minHeight: 110)
      }

      Section("基本信息") {
        TextField("昵称", text: $nickname)
          .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
        TextField("当前年级（可选）", text: $grade)
          .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
      }

      Section("选择头像") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 12)], spacing: 12) {
          ForEach(avatarSymbols, id: \.self) { symbol in
            Button {
              avatarSymbol = symbol
            } label: {
              Image(systemName: symbol)
                .guozaiScaledSystemFont(size: 24, weight: .bold)
                .foregroundStyle(avatarSymbol == symbol ? .white : GuozaiColor.oceanDeep)
                .frame(width: 56, height: 56)
                .background(avatarSymbol == symbol ? GuozaiColor.ocean : GuozaiColor.oceanSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择\(avatarTitle(symbol))头像")
            .accessibilityValue(avatarSymbol == symbol ? "已选择" : "未选择")
            .accessibilityAddTraits(avatarSymbol == symbol ? .isSelected : [])
          }
        }
        .padding(.vertical, GuozaiSpacing.small)
      }

      Section {
        Text("首版只有一个本地成长档案，不需要账号，也不会要求真实姓名。")
          .foregroundStyle(GuozaiColor.inkMuted)
      }
    }
    .scrollContentBackground(.hidden)
    .background(GuozaiColor.canvasWarm)
    .navigationTitle("成长档案")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("保存", action: save)
          .fontWeight(.bold)
          .frame(minHeight: 52)
          .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .task { loadProfile() }
    .onChange(of: profiles.first?.id) { _, _ in loadProfile() }
    .alert("已保存", isPresented: $savedNotice) {
      Button("好", role: .cancel) {}
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
  private func loadProfile() {
    do {
      let profile = try SeedService.ensureSeeded(in: modelContext)
      guard loadedProfileID != profile.id else { return }
      loadedProfileID = profile.id
      nickname = profile.nickname
      grade = profile.grade ?? ""
      avatarSymbol = profile.avatarSymbol ?? "face.smiling.fill"
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func save() {
    guard let profile = profiles.first else { return }
    profile.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanedGrade = grade.trimmingCharacters(in: .whitespacesAndNewlines)
    profile.grade = cleanedGrade.isEmpty ? nil : cleanedGrade
    profile.avatarSymbol = avatarSymbol
    profile.updatedAt = .now
    do {
      try PersistenceWriter.save(modelContext)
      savedNotice = true
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }

  private func avatarTitle(_ symbol: String) -> String {
    switch symbol {
    case "face.smiling.fill": "笑脸"
    case "sun.max.fill": "太阳"
    case "star.fill": "星星"
    case "leaf.fill": "叶子"
    case "book.fill": "书本"
    case "figure.run.circle.fill": "跑步"
    case "paintpalette.fill": "画画"
    case "music.note": "音乐"
    default: "成长"
    }
  }
}
