import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    private static let maximumBackupBytes = 25 * 1_024 * 1_024

    @Environment(\.modelContext) private var modelContext

    @State private var jsonDocument: JSONBackupDocument?
    @State private var csvDocument: CSVExportDocument?
    @State private var csvFilename = ""
    @State private var isExportingJSON = false
    @State private var isExportingCSV = false
    @State private var isImportingJSON = false
    @State private var importCandidate: BackupImportCandidate?
    @State private var notice: OperationNotice?
    @State private var presentedError: PresentedBackupError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                privacyNote

                if let notice {
                    NoticeCard(notice: notice)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                sectionCard(
                    title: "完整备份",
                    subtitle: "明文 JSON 包含任务模板、每日记录、回顾、勋章与心愿奖励。保存时可在系统“文件”中选择 iCloud Drive。",
                    symbol: "externaldrive.badge.icloud",
                    tint: ParentPalette.leaf
                ) {
                    actionButton(
                        title: "导出完整 JSON",
                        subtitle: "适合备份、迁移和后续恢复",
                        symbol: "square.and.arrow.up.fill",
                        tint: ParentPalette.leaf,
                        action: prepareJSONExport
                    )

                    Divider().overlay(ParentPalette.line)

                    actionButton(
                        title: "导入 JSON 备份",
                        subtitle: "先检查内容，再确认合并；不会覆盖已有 UUID",
                        symbol: "tray.and.arrow.down.fill",
                        tint: ParentPalette.ocean
                    ) {
                        isImportingJSON = true
                    }
                }

                sectionCard(
                    title: "分析 CSV",
                    subtitle: "导出的 UTF-8 表格可直接交给 Numbers、Excel 或后续可视化程序使用。",
                    symbol: "chart.xyaxis.line",
                    tint: ParentPalette.mango
                ) {
                    ForEach(Array(AnalyticsCSVKind.allCases.enumerated()), id: \.element.id) { index, kind in
                        if index > 0 {
                            Divider().overlay(ParentPalette.line)
                        }
                        actionButton(
                            title: "导出\(kind.title) CSV",
                            subtitle: kind.subtitle,
                            symbol: kind.symbol,
                            tint: ParentPalette.mango
                        ) {
                            prepareCSVExport(kind)
                        }
                    }
                }

                Text("小提示：JSON 和 CSV 都是可读明文，请只保存到你信任的位置。App 不会自动上传数据。")
                    .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
                    .foregroundStyle(ParentPalette.inkSecondary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(20)
        }
        .background(ParentPalette.paper.ignoresSafeArea())
        .navigationTitle("数据管理")
        .fileExporter(
            isPresented: $isExportingJSON,
            document: jsonDocument,
            contentType: .json,
            defaultFilename: "果仔的一天-完整备份-\(todayKey)"
        ) { result in
            handleExportResult(result, label: "JSON 备份")
        }
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: csvFilename
        ) { result in
            handleExportResult(result, label: "CSV")
        }
        .fileImporter(
            isPresented: $isImportingJSON,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .sheet(item: $importCandidate) { candidate in
            BackupPreviewSheet(candidate: candidate) {
                merge(candidate)
            }
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text("操作未完成"),
                message: Text(error.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .animation(.easeOut(duration: 0.22), value: notice)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "lock.shield.fill")
                .guozaiScaledSystemFont(size: 25, weight: .semibold)
                .foregroundStyle(ParentPalette.leaf)
                .frame(width: 50, height: 50)
                .background(ParentPalette.leaf.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 5) {
                Text("数据由你掌握")
                    .guozaiScaledSystemFont(size: 21, weight: .bold, design: .rounded)
                    .foregroundStyle(ParentPalette.ink)
                Text("默认只保存在设备本地。导入前会展示版本、日期范围和记录数量。")
                    .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
                    .foregroundStyle(ParentPalette.inkSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(20)
        .background(ParentPalette.leaf.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(ParentPalette.leaf.opacity(0.22), lineWidth: 1)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .guozaiScaledSystemFont(size: 24, weight: .semibold)
                    .foregroundStyle(tint)
                    .frame(width: 50, height: 50)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .guozaiScaledSystemFont(size: 22, weight: .bold, design: .rounded)
                        .foregroundStyle(ParentPalette.ink)
                    Text(subtitle)
                        .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
                        .foregroundStyle(ParentPalette.inkSecondary)
                        .lineSpacing(3)
                }
            }

            content()
        }
        .padding(20)
        .background(ParentPalette.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(ParentPalette.line, lineWidth: 1)
        }
        .shadow(color: ParentPalette.shadow, radius: 12, y: 5)
    }

    private func actionButton(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .guozaiScaledSystemFont(size: 20, weight: .semibold)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .guozaiScaledSystemFont(size: 18, weight: .bold, design: .rounded)
                        .foregroundStyle(ParentPalette.ink)
                    Text(subtitle)
                        .guozaiScaledSystemFont(size: 14, weight: .medium, design: .rounded)
                        .foregroundStyle(ParentPalette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .guozaiScaledSystemFont(size: 15, weight: .bold)
                    .foregroundStyle(ParentPalette.inkSecondary.opacity(0.7))
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(subtitle)
    }

    private func prepareJSONExport() {
        do {
            jsonDocument = try AppBackupService.makeJSONDocument(in: modelContext)
            isExportingJSON = true
        } catch {
            present(error)
        }
    }

    private func prepareCSVExport(_ kind: AnalyticsCSVKind) {
        do {
            csvDocument = try AnalyticsCSVService.document(kind, in: modelContext)
            csvFilename = "果仔的一天-\(kind.fileLabel)-\(todayKey)"
            isExportingCSV = true
        } catch {
            present(error)
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize <= Self.maximumBackupBytes else {
                throw BackupFileSelectionError.fileTooLarge
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            importCandidate = try AppBackupService.candidate(from: data)
        } catch {
            present(error)
        }
    }

    private func merge(_ candidate: BackupImportCandidate) {
        do {
            let result = try AppBackupService.merge(candidate.payload, into: modelContext)
            importCandidate = nil
            notice = OperationNotice(
                symbol: "checkmark.shield.fill",
                message: "导入完成：新增 \(result.insertedTotal) 条，跳过已有 \(result.skippedTotal) 条。"
            )
        } catch {
            importCandidate = nil
            present(error)
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>, label: String) {
        switch result {
        case .success:
            notice = OperationNotice(symbol: "checkmark.circle.fill", message: "\(label)已保存。")
        case let .failure(error):
            present(error)
        }
    }

    private func present(_ error: Error) {
        let message: String
        if let codecError = error as? BackupCodecError {
            switch codecError {
            case let .unsupportedSchemaVersion(version):
                message = "备份版本 v\(version) 暂不支持，请先更新 App。"
            }
        } else if error is DecodingError {
            message = "这不是有效的“果仔的一天”JSON 备份。"
        } else {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        presentedError = PresentedBackupError(message: message)
    }

    private var todayKey: String { LocalDay(date: .now).key }
}

private enum BackupFileSelectionError: LocalizedError {
    case fileTooLarge

    var errorDescription: String? {
        "备份文件超过 25 MB，请确认选择的是“果仔的一天”完整 JSON 备份。"
    }
}

private struct BackupPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let candidate: BackupImportCandidate
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .guozaiScaledSystemFont(size: 28, weight: .semibold)
                            .foregroundStyle(ParentPalette.ocean)
                            .frame(width: 58, height: 58)
                            .background(ParentPalette.ocean.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("先看看备份里有什么")
                                .guozaiScaledSystemFont(size: 23, weight: .bold, design: .rounded)
                                .foregroundStyle(ParentPalette.ink)
                            Text("确认前不会写入任何数据")
                                .guozaiScaledSystemFont(size: 16, weight: .medium, design: .rounded)
                                .foregroundStyle(ParentPalette.inkSecondary)
                        }
                    }

                    VStack(spacing: 0) {
                        PreviewInfoRow(label: "数据版本", value: "v\(candidate.preview.schemaVersion)")
                        PreviewInfoRow(label: "App 版本", value: candidate.preview.appVersion)
                        PreviewInfoRow(
                            label: "导出时间",
                            value: candidate.preview.exportedAt.formatted(date: .numeric, time: .shortened)
                        )
                        PreviewInfoRow(label: "记录日期", value: candidate.preview.dateRangeText, showsDivider: false)
                    }
                    .background(ParentPalette.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22).stroke(ParentPalette.line, lineWidth: 1)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 138), spacing: 12)],
                        spacing: 12
                    ) {
                        PreviewCountCard(title: "成长档案", count: candidate.preview.profileCount, symbol: "person.fill")
                        PreviewCountCard(title: "任务模板", count: candidate.preview.templateCount, symbol: "checklist")
                        PreviewCountCard(title: "每日任务", count: candidate.preview.taskCount, symbol: "calendar")
                        PreviewCountCard(title: "已打卡", count: candidate.preview.checkInCount, symbol: "checkmark.circle.fill")
                        PreviewCountCard(title: "每日回顾", count: candidate.preview.reflectionCount, symbol: "text.bubble.fill")
                        PreviewCountCard(title: "勋章", count: candidate.preview.badgeCount, symbol: "medal.fill")
                        PreviewCountCard(title: "心愿奖励", count: candidate.preview.rewardCount, symbol: "gift.fill")
                    }

                    Label(
                        "单档案规则：备份会归入本机果仔；若本机只有未使用的初始示例，会先替换示例。其余记录按稳定 UUID 合并，已有记录不会静默覆盖。",
                        systemImage: "shield.lefthalf.filled"
                    )
                    .guozaiScaledSystemFont(size: 16, weight: .semibold, design: .rounded)
                    .foregroundStyle(ParentPalette.leaf)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ParentPalette.leaf.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))

                    Button(action: onConfirm) {
                        Label("确认合并数据", systemImage: "arrow.triangle.merge")
                            .guozaiScaledSystemFont(size: 19, weight: .bold, design: .rounded)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ParentPalette.leaf)
                }
                .frame(maxWidth: 700, alignment: .leading)
                .padding(20)
            }
            .background(ParentPalette.paper.ignoresSafeArea())
            .navigationTitle("导入预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PreviewInfoRow: View {
    let label: String
    let value: String
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(label)
                    .foregroundStyle(ParentPalette.inkSecondary)
                Spacer()
                Text(value)
                    .foregroundStyle(ParentPalette.ink)
                    .multilineTextAlignment(.trailing)
            }
            .guozaiScaledSystemFont(size: 16, weight: .semibold, design: .rounded)
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            if showsDivider {
                Divider().overlay(ParentPalette.line).padding(.leading, 18)
            }
        }
    }
}

private struct PreviewCountCard: View {
    let title: String
    let count: Int
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .guozaiScaledSystemFont(size: 20, weight: .semibold)
                .foregroundStyle(ParentPalette.ocean)
                .frame(width: 40, height: 40)
                .background(ParentPalette.ocean.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text(count, format: .number)
                    .guozaiScaledSystemFont(size: 22, weight: .bold, design: .rounded)
                    .foregroundStyle(ParentPalette.ink)
                Text(title)
                    .guozaiScaledSystemFont(size: 13, weight: .semibold, design: .rounded)
                    .foregroundStyle(ParentPalette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 72)
        .background(ParentPalette.card, in: RoundedRectangle(cornerRadius: 19))
        .overlay {
            RoundedRectangle(cornerRadius: 19).stroke(ParentPalette.line, lineWidth: 1)
        }
    }
}

private struct NoticeCard: View {
    let notice: OperationNotice

    var body: some View {
        Label(notice.message, systemImage: notice.symbol)
            .guozaiScaledSystemFont(size: 16, weight: .bold, design: .rounded)
            .foregroundStyle(ParentPalette.leaf)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ParentPalette.leaf.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct OperationNotice: Equatable {
    let symbol: String
    let message: String
}

private struct PresentedBackupError: Identifiable {
    let id = UUID()
    let message: String
}
