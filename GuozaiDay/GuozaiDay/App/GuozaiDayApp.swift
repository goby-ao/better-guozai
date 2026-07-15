import SwiftData
import SwiftUI

@main
struct GuozaiDayApp: App {
    private let modelContainer: ModelContainer
    private let storageErrorMessage: String?

    init() {
        do {
            modelContainer = try PersistenceModels.makeContainer()
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = error.localizedDescription
            do {
                modelContainer = try PersistenceModels.makeContainer(inMemory: true)
            } catch {
                fatalError("无法初始化成长数据存储：\(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let storageErrorMessage {
                    StorageUnavailableView(detail: storageErrorMessage)
                } else {
                    AppShellView()
                }
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}

private struct StorageUnavailableView: View {
    let detail: String

    var body: some View {
        ContentUnavailableView {
            Label("暂时无法打开成长数据", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("为避免打卡记录丢失，App 已暂停编辑。请确认设备仍有可用空间，然后重新打开 App。\n\n\(detail)")
        }
        .padding(32)
        .background(GuozaiColor.canvasWarm.ignoresSafeArea())
    }
}
