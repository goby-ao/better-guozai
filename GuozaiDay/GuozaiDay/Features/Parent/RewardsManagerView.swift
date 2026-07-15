import SwiftData
import SwiftUI

struct RewardsManagerView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
  @Query(sort: \BadgeAwardRecord.awardedAt, order: .reverse) private var awards: [BadgeAwardRecord]
  @Query(sort: \WishRewardRecord.createdAt, order: .reverse) private var rewards: [WishRewardRecord]

  @State private var presentedSheet: RewardsManagerSheet?
  @State private var errorMessage: String?

  private var profileID: UUID? { profiles.first?.id }

  private var specialAwards: [BadgeAwardRecord] {
    guard let profileID else { return [] }
    return awards.filter { $0.profileId == profileID && $0.source == .parent }
  }

  private var profileRewards: [WishRewardRecord] {
    guard let profileID else { return [] }
    return rewards.filter { $0.profileId == profileID }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: GuozaiSpacing.xLarge) {
        intro
        actions
        specialBadgesSection
        wishesSection
      }
      .frame(maxWidth: GuozaiLayout.readableContentWidth, alignment: .leading)
      .padding(.horizontal, GuozaiSpacing.large)
      .padding(.vertical, GuozaiSpacing.xLarge)
      .frame(maxWidth: .infinity)
    }
    .background(GuozaiColor.canvasWarm.ignoresSafeArea())
    .navigationTitle("勋章与心愿")
    .navigationBarTitleDisplayMode(.inline)
    .task { ensureProfileExists() }
    .sheet(item: $presentedSheet) { destination in
      NavigationStack {
        switch destination {
        case .specialBadge:
          SpecialBadgeEditorView()
        case .wishReward:
          WishRewardEditorView()
        }
      }
      .presentationDetents([.large])
    }
    .alert("暂时没有保存", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private var intro: some View {
    HStack(alignment: .center, spacing: GuozaiSpacing.large) {
      Image(systemName: "medal.fill")
        .guozaiScaledSystemFont(size: 30, weight: .bold)
        .foregroundStyle(GuozaiColor.mango)
        .frame(width: 64, height: 64)
        .background(GuozaiColor.mangoSoft, in: RoundedRectangle(cornerRadius: 20))

      VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
        Text("把成长变成温暖的纪念")
          .guozaiTextStyle(.sectionTitle)
          .foregroundStyle(GuozaiColor.ink)
        Text("特别勋章永久保留；果仔自己选心愿，靠一周里的认真达成解锁。")
          .guozaiTextStyle(.body)
          .foregroundStyle(GuozaiColor.inkMuted)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var actions: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 250), spacing: GuozaiSpacing.medium)],
      spacing: GuozaiSpacing.medium
    ) {
      ManagerActionButton(
        title: "颁发特别勋章",
        subtitle: "记录一个值得珍藏的成长瞬间",
        symbol: "rosette",
        tint: GuozaiColor.coral
      ) {
        presentedSheet = .specialBadge
      }

      ManagerActionButton(
        title: "创建心愿奖励",
        subtitle: "关联勋章，或创建一个 5/7 周心愿",
        symbol: "gift.fill",
        tint: GuozaiColor.ocean
      ) {
        presentedSheet = .wishReward
      }
    }
  }

  private var specialBadgesSection: some View {
    PaperSection(
      "已颁发的特别勋章",
      subtitle: "已获得的勋章不会删除，成长故事会一直保留。",
      systemImage: "heart.circle.fill"
    ) {
      if specialAwards.isEmpty {
        EmptyManagerRow(
          title: "还没有特别勋章",
          detail: "发现果仔独一无二的进步时，就为他点亮一枚吧。",
          symbol: "sparkles"
        )
      } else {
        VStack(spacing: GuozaiSpacing.medium) {
          ForEach(specialAwards) { award in
            SpecialAwardRow(award: award)
          }
        }
      }
    }
  }

  private var wishesSection: some View {
    PaperSection(
      "心愿清单",
      subtitle: "周心愿由果仔选择；解锁后由家长确认领取。",
      systemImage: "gift.circle.fill"
    ) {
      if profileRewards.isEmpty {
        EmptyManagerRow(
          title: "还没有心愿奖励",
          detail: "可以是一场亲子活动、一次新体验，或一本期待的书。",
          symbol: "wand.and.stars"
        )
      } else {
        VStack(spacing: GuozaiSpacing.medium) {
          ForEach(profileRewards) { reward in
            WishManagerRow(reward: reward) {
              toggleClaimed(reward)
            }
          }
        }
      }
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  @MainActor
  private func ensureProfileExists() {
    do {
      _ = try SeedService.ensureSeeded(in: modelContext)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func toggleClaimed(_ reward: WishRewardRecord) {
    guard reward.state == .unlocked || reward.state == .claimed else { return }

    if reward.state == .unlocked {
      reward.state = .claimed
      reward.claimedAt = .now
    } else {
      reward.state = .unlocked
      reward.claimedAt = nil
    }

    do {
      try PersistenceWriter.save(modelContext)
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }
}

private enum RewardsManagerSheet: String, Identifiable {
  case specialBadge
  case wishReward

  var id: String { rawValue }
}

private struct ManagerActionButton: View {
  let title: String
  let subtitle: String
  let symbol: String
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: GuozaiSpacing.medium) {
        Image(systemName: symbol)
          .guozaiScaledSystemFont(size: 25, weight: .bold)
          .foregroundStyle(tint)
          .frame(width: 54, height: 54)
          .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))

        VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
          Text(title)
            .guozaiTextStyle(.control)
            .foregroundStyle(GuozaiColor.ink)
          Text(subtitle)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(GuozaiColor.inkMuted)
            .multilineTextAlignment(.leading)
        }
        Spacer(minLength: 8)
        Image(systemName: "plus.circle.fill")
          .font(.title2)
          .foregroundStyle(tint)
      }
      .padding(GuozaiSpacing.medium)
      .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      .background(GuozaiColor.paper, in: RoundedRectangle(cornerRadius: GuozaiRadius.section))
      .overlay {
        RoundedRectangle(cornerRadius: GuozaiRadius.section)
          .stroke(tint.opacity(0.32), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint("打开编辑页")
  }
}

private struct EmptyManagerRow: View {
  let title: String
  let detail: String
  let symbol: String

  var body: some View {
    HStack(spacing: GuozaiSpacing.medium) {
      Image(systemName: symbol)
        .font(.title2.bold())
        .foregroundStyle(GuozaiColor.mango)
        .frame(width: 52, height: 52)
        .background(GuozaiColor.mangoSoft, in: Circle())
      VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
        Text(title)
          .guozaiTextStyle(.control)
          .foregroundStyle(GuozaiColor.ink)
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(GuozaiColor.inkMuted)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct SpecialAwardRow: View {
  let award: BadgeAwardRecord

  var body: some View {
    HStack(alignment: .top, spacing: GuozaiSpacing.medium) {
      Image(systemName: award.symbol)
        .guozaiScaledSystemFont(size: 26, weight: .bold)
        .foregroundStyle(GuozaiColor.coral)
        .frame(width: 58, height: 58)
        .background(GuozaiColor.coralSoft, in: Circle())

      VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
        Text(award.title)
          .guozaiTextStyle(.control)
          .foregroundStyle(GuozaiColor.ink)
        Text(award.detail)
          .font(.body)
          .foregroundStyle(GuozaiColor.inkMuted)
          .fixedSize(horizontal: false, vertical: true)
        Text(award.awardedAt.formatted(.dateTime.year().month().day()))
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(GuozaiColor.coral)
      }
      Spacer(minLength: 0)
    }
    .padding(GuozaiSpacing.medium)
    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
    .background(GuozaiColor.coralSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
    .accessibilityElement(children: .combine)
  }
}

private struct WishManagerRow: View {
  let reward: WishRewardRecord
  let toggleClaimed: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
      HStack(alignment: .top, spacing: GuozaiSpacing.medium) {
        Image(systemName: stateSymbol)
          .guozaiScaledSystemFont(size: 25, weight: .bold)
          .foregroundStyle(stateTint)
          .frame(width: 56, height: 56)
          .background(stateTint.opacity(0.13), in: Circle())

        VStack(alignment: .leading, spacing: GuozaiSpacing.xSmall) {
          HStack {
            Text(reward.title)
              .guozaiTextStyle(.control)
              .foregroundStyle(GuozaiColor.ink)
            Spacer()
            Text(stateTitle)
              .font(.caption.weight(.bold))
              .foregroundStyle(stateTint)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(stateTint.opacity(0.12), in: Capsule())
          }

          if !reward.detail.isEmpty {
            Text(reward.detail)
              .font(.body)
              .foregroundStyle(GuozaiColor.inkMuted)
          }


          if reward.state == .locked, reward.weeklyTarget != nil, reward.selectedAt != nil {
            Label("果仔当前选择", systemImage: "heart.fill")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(GuozaiColor.leaf)
          }

          Label(conditionTitle, systemImage: "calendar.badge.checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GuozaiColor.inkMuted)
        }
      }

      if reward.state == .unlocked || reward.state == .claimed {
        Button(reward.state == .claimed ? "撤销领取" : "标为已领取", action: toggleClaimed)
          .guozaiScaledSystemFont(size: 17, weight: .bold, design: .rounded)
          .buttonStyle(.borderedProminent)
          .tint(reward.state == .claimed ? GuozaiColor.inkMuted : GuozaiColor.ocean)
          .frame(maxWidth: .infinity, minHeight: 52, alignment: .trailing)
          .accessibilityHint(reward.state == .claimed ? "恢复为已解锁状态" : "确认心愿已经兑现")
      }
    }
    .padding(GuozaiSpacing.medium)
    .background(GuozaiColor.canvasWarm.opacity(0.6), in: RoundedRectangle(cornerRadius: GuozaiRadius.control))
  }

  private var conditionTitle: String {
    if let badgeID = reward.linkedBadgeId,
       let code = BadgeCode(rawValue: badgeID) {
      return "获得“\(BadgePresentation(code: code).title)”后解锁"
    }
    if let target = reward.weeklyTarget {
      return reward.selectedAt == nil
        ? "等待果仔选择，选中后本周达成 \(target) 天解锁"
        : "本周达成 \(target) 天后解锁"
    }
    return "等待成长条件"
  }

  private var stateTitle: String {
    switch reward.state {
    case .locked: "成长中"
    case .unlocked: "已解锁"
    case .claimed: "已领取"
    }
  }

  private var stateSymbol: String {
    switch reward.state {
    case .locked: "lock.fill"
    case .unlocked: "party.popper.fill"
    case .claimed: "checkmark.seal.fill"
    }
  }

  private var stateTint: Color {
    switch reward.state {
    case .locked: GuozaiColor.inkMuted
    case .unlocked: GuozaiColor.mango
    case .claimed: GuozaiColor.leaf
    }
  }
}

private struct SpecialBadgeEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var title = ""
  @State private var reason = ""
  @State private var symbol = "star.fill"
  @State private var errorMessage: String?

  private let symbols = [
    "star.fill", "heart.fill", "hands.and.sparkles.fill", "figure.arms.open",
    "book.fill", "figure.run", "leaf.fill", "lightbulb.fill"
  ]

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Form {
      Section {
        TextField("勋章名称", text: $title)
          .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
        TextField("为什么值得这枚勋章", text: $reason, axis: .vertical)
          .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
          .lineLimit(3...6)
          .frame(minHeight: 88, alignment: .top)
      } header: {
        Text("特别勋章")
      } footer: {
        Text("写下具体的成长瞬间，果仔以后回看时会更有意义。")
      }

      Section("选择图案") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 12)], spacing: 12) {
          ForEach(symbols, id: \.self) { candidate in
            Button {
              symbol = candidate
            } label: {
              Image(systemName: candidate)
                .guozaiScaledSystemFont(size: 23, weight: .bold)
                .foregroundStyle(symbol == candidate ? Color.white : GuozaiColor.coral)
                .frame(width: 56, height: 56)
                .background(symbol == candidate ? GuozaiColor.coral : GuozaiColor.coralSoft, in: Circle())
                .overlay {
                  Circle().stroke(GuozaiColor.coral.opacity(symbol == candidate ? 1 : 0.3), lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择图案 \(candidate)")
            .accessibilityAddTraits(symbol == candidate ? .isSelected : [])
          }
        }
        .padding(.vertical, 6)
      }
    }
    .scrollContentBackground(.hidden)
    .background(GuozaiColor.canvasWarm)
    .navigationTitle("颁发特别勋章")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { dismiss() }
          .frame(minHeight: 52)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("颁发") { save() }
          .fontWeight(.bold)
          .disabled(!canSave)
          .frame(minHeight: 52)
      }
    }
    .alert("暂时没有保存", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  @MainActor
  private func save() {
    do {
      let profile = try SeedService.ensureSeeded(in: modelContext)
      let awardID = UUID()
      modelContext.insert(BadgeAwardRecord(
        id: awardID,
        profileId: profile.id,
        stableBadgeId: "parent-\(awardID.uuidString.lowercased())",
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        detail: reason.trimmingCharacters(in: .whitespacesAndNewlines),
        symbol: symbol,
        source: .parent
      ))
      try PersistenceWriter.save(modelContext)
      dismiss()
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }
}

private struct WishRewardEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var title = ""
  @State private var detail = ""
  @State private var condition: WishCondition = .systemBadge
  @State private var selectedBadgeID = BadgeCode.firstCheckIn.rawValue
  @State private var errorMessage: String?

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Form {
      Section("心愿内容") {
        TextField("心愿名称", text: $title)
          .guozaiScaledSystemFont(size: 18, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
        TextField("说明（可选）", text: $detail, axis: .vertical)
          .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
          .lineLimit(2...5)
          .frame(minHeight: 72, alignment: .top)
      }

      Section {
        Picker("条件类型", selection: $condition) {
          ForEach(WishCondition.allCases) { value in
            Text(value.title).tag(value)
          }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 52)

        if condition == .systemBadge {
          Picker("关联系统勋章", selection: $selectedBadgeID) {
            ForEach(BadgeCode.allCases, id: \.rawValue) { code in
              let presentation = BadgePresentation(code: code)
              Label(presentation.title, systemImage: presentation.symbol)
                .tag(code.rawValue)
            }
          }
          .guozaiScaledSystemFont(size: 17, weight: .semibold, design: .rounded)
          .frame(minHeight: 52)
        } else {
          VStack(alignment: .leading, spacing: GuozaiSpacing.medium) {
            Label("一周达成 5 天", systemImage: "calendar.badge.checkmark")
              .guozaiScaledSystemFont(size: 18, weight: .bold, design: .rounded)
              .foregroundStyle(GuozaiColor.ink)

            HStack(spacing: GuozaiSpacing.small) {
              ForEach(0..<7, id: \.self) { index in
                Circle()
                  .fill(index < 5 ? GuozaiColor.leafSoft : GuozaiColor.canvasWarm)
                  .overlay {
                    Circle().stroke(index == 4 ? GuozaiColor.mango : GuozaiColor.line, lineWidth: index == 4 ? 2 : 1)
                  }
                  .frame(width: 25, height: 25)
                  .overlay {
                    if index < 5 {
                      Image(systemName: "leaf.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(GuozaiColor.leaf)
                    }
                  }
              }
            }

            Text("果仔先从心愿清单里选一个；一周内有 5 天完成全部必做任务，就会自动解锁。")
              .font(.subheadline)
              .foregroundStyle(GuozaiColor.inkMuted)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.vertical, GuozaiSpacing.small)
        }
      } header: {
        Text("解锁条件")
      } footer: {
        Text("勋章心愿按勋章解锁；周心愿固定采用温和的 5/7 节奏。")
      }
    }
    .scrollContentBackground(.hidden)
    .background(GuozaiColor.canvasWarm)
    .navigationTitle("创建心愿奖励")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { dismiss() }
          .frame(minHeight: 52)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("创建") { save() }
          .fontWeight(.bold)
          .disabled(!canSave)
          .frame(minHeight: 52)
      }
    }
    .alert("暂时没有保存", isPresented: errorPresented) {
      Button("知道了", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  @MainActor
  private func save() {
    do {
      let profile = try SeedService.ensureSeeded(in: modelContext)
      modelContext.insert(WishRewardRecord(
        profileId: profile.id,
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
        linkedBadgeId: condition == .systemBadge ? selectedBadgeID : nil,
        weeklyTarget: condition == .weeklyDays ? WishRewardStore.weeklyTarget : nil
      ))
      try PersistenceWriter.save(modelContext)
      try AchievementStore.evaluate(profileId: profile.id, in: modelContext)
      dismiss()
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }
}

private enum WishCondition: String, CaseIterable, Identifiable {
  case systemBadge
  case weeklyDays

  var id: String { rawValue }

  var title: String {
    switch self {
    case .systemBadge: "系统勋章"
    case .weeklyDays: "每周 5/7"
    }
  }
}
