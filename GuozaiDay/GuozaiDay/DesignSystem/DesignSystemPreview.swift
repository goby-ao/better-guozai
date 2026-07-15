#if DEBUG
import SwiftUI

private struct DesignSystemPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuozaiSpacing.xLarge) {
                HStack(alignment: .center, spacing: GuozaiSpacing.large) {
                    DateStamp(date: .now)

                    VStack(alignment: .leading, spacing: GuozaiSpacing.small) {
                        Text("果仔的一天")
                            .guozaiTextStyle(.pageTitle)
                            .foregroundStyle(GuozaiColor.oceanDeep)

                        Text("每天一点点，长成自己的样子")
                            .guozaiTextStyle(.body)
                            .foregroundStyle(GuozaiColor.inkMuted)
                    }
                }

                PaperSection("今日计划", subtitle: "完成一项，就为今天点亮一颗星", systemImage: "checklist") {
                    Text("阅读 30 分钟")
                        .guozaiTextStyle(.task)
                        .foregroundStyle(GuozaiColor.ink)

                    PrimaryButton("完成今日回顾", systemImage: "sparkles") { }
                }
            }
            .padding(GuozaiSpacing.xLarge)
            .frame(maxWidth: GuozaiLayout.readableContentWidth)
        }
        .background(GuozaiColor.canvasWarm)
    }
}

#Preview("Design system") {
    DesignSystemPreviewGallery()
}
#endif
