import SwiftData
import SwiftUI

struct ParentHomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var errorMessage: String?

  private let columns = [
    GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 18)
  ]

  var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header

          LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ParentModuleLink(
              title: "成长档案",
              subtitle: "编辑果仔的昵称、年级和头像",
              symbol: "person.crop.circle.fill",
              tint: ParentPalette.ocean
            ) {
              ProfileSettingsView()
            }

            ParentModuleLink(
              title: "任务模板",
              subtitle: "安排每天、工作日或自定义日的成长任务",
              symbol: "checklist",
              tint: ParentPalette.mango
            ) {
              TemplateManagerView()
            }

            ParentModuleLink(
              title: "历史记录",
              subtitle: "回看每天的完成情况，并修正误操作",
              symbol: "calendar.badge.clock",
              tint: ParentPalette.ocean
            ) {
              HistoryBrowserView()
            }

            ParentModuleLink(
              title: "成长分析",
              subtitle: "查看趋势、六个成长领域和最近两周矩阵",
              symbol: "chart.xyaxis.line",
              tint: ParentPalette.leaf
            ) {
              ParentAnalyticsView()
            }

            ParentModuleLink(
              title: "提醒设置",
              subtitle: "规划早晚提醒与任务提醒",
              symbol: "bell.badge.fill",
              tint: ParentPalette.coral
            ) {
              ReminderSettingsView()
            }

            ParentModuleLink(
              title: "勋章与心愿",
              subtitle: "颁发特别勋章，设置成长后的心愿惊喜",
              symbol: "medal.fill",
              tint: ParentPalette.mango
            ) {
              RewardsManagerView()
            }

            ParentModuleLink(
              title: "数据管理",
              subtitle: "导出、导入与备份成长记录",
              symbol: "externaldrive.badge.icloud",
              tint: ParentPalette.leaf
            ) {
              DataManagementView()
            }
          }

          Text("家长可以调整计划，果仔只需要专注今天。历史修正会保留原日期和修改时间。")
            .guozaiScaledSystemFont(size: 17, weight: .medium, design: .rounded)
            .foregroundStyle(ParentPalette.inkSecondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 980 : .infinity, alignment: .leading)
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
        .padding(.vertical, 24)
      }
      .background(ParentPalette.paper.ignoresSafeArea())
      .navigationTitle("家长区")
      .navigationBarTitleDisplayMode(.large)
      .task {
        do {
          _ = try SeedService.ensureSeeded(in: modelContext)
        } catch {
          errorMessage = error.localizedDescription
        }
      }
      .alert("暂时无法准备家长区", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) {
        Button("知道了", role: .cancel) { errorMessage = nil }
      } message: {
        Text(errorMessage ?? "请稍后再试。")
      }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 16) {
      Image(systemName: "hands.and.sparkles.fill")
        .guozaiScaledSystemFont(size: 30, weight: .semibold)
        .foregroundStyle(ParentPalette.mango)
        .frame(width: 62, height: 62)
        .background(ParentPalette.mango.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))

      VStack(alignment: .leading, spacing: 5) {
        Text("一起守护成长")
          .guozaiScaledSystemFont(size: 27, weight: .bold, design: .rounded)
          .foregroundStyle(ParentPalette.ink)
        Text("计划清楚一点，鼓励多一点")
          .guozaiScaledSystemFont(size: 18, weight: .medium, design: .rounded)
          .foregroundStyle(ParentPalette.inkSecondary)
      }
    }
  }
}

private struct ParentModuleLink<Destination: View>: View {
  let title: String
  let subtitle: String
  let symbol: String
  let tint: Color
  let destination: Destination

  init(
    title: String,
    subtitle: String,
    symbol: String,
    tint: Color,
    @ViewBuilder destination: () -> Destination
  ) {
    self.title = title
    self.subtitle = subtitle
    self.symbol = symbol
    self.tint = tint
    self.destination = destination()
  }

  var body: some View {
    NavigationLink(destination: destination) {
      HStack(spacing: 16) {
        Image(systemName: symbol)
          .guozaiScaledSystemFont(size: 26, weight: .semibold)
          .foregroundStyle(tint)
          .frame(width: 54, height: 54)
          .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))

        VStack(alignment: .leading, spacing: 6) {
          Text(title)
            .guozaiScaledSystemFont(size: 21, weight: .bold, design: .rounded)
            .foregroundStyle(ParentPalette.ink)
          Text(subtitle)
            .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
            .foregroundStyle(ParentPalette.inkSecondary)
            .multilineTextAlignment(.leading)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .guozaiScaledSystemFont(size: 17, weight: .bold)
          .foregroundStyle(ParentPalette.inkSecondary.opacity(0.75))
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
      .background(ParentPalette.card, in: RoundedRectangle(cornerRadius: 24))
      .overlay {
        RoundedRectangle(cornerRadius: 24)
          .stroke(ParentPalette.line, lineWidth: 1)
      }
      .shadow(color: ParentPalette.shadow, radius: 14, y: 6)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint("打开\(title)")
  }
}

enum ParentPalette {
  static let paper = Color(red: 0.974, green: 0.949, blue: 0.887)
  static let card = Color(red: 1.0, green: 0.988, blue: 0.951)
  static let ink = Color(red: 0.20, green: 0.25, blue: 0.25)
  static let inkSecondary = Color(red: 0.38, green: 0.42, blue: 0.40)
  static let line = Color(red: 0.78, green: 0.72, blue: 0.59).opacity(0.45)
  static let shadow = Color.black.opacity(0.07)
  static let mango = Color(red: 0.93, green: 0.58, blue: 0.16)
  static let ocean = Color(red: 0.15, green: 0.50, blue: 0.60)
  static let coral = Color(red: 0.84, green: 0.38, blue: 0.31)
  static let leaf = Color(red: 0.32, green: 0.55, blue: 0.35)
}
