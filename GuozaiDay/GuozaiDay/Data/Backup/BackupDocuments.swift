import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    let content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let content = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.content = content
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // UTF-8 BOM helps Excel and Numbers recognize Chinese text reliably.
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
