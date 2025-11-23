import Foundation

// MARK: - JournalWriter

struct JournalWriter {
    // MARK: Properties

    let fileManager: FileWorker

    // MARK: Lifecycle

    init(fileManager: FileWorker = SystemFileWorker()) {
        self.fileManager = fileManager
    }

    // MARK: Functions

    func ensureDirectoryExists(at path: String) throws {
        if !fileManager.fileExists(at: path) {
            try fileManager
                .createDirectory(
                    at: path,
                    createIntermediates: true,
                    attributes: nil,
                )
        }
    }

    func appendToJournalFile(at filePath: String, content: String) throws {
        if fileManager.fileExists(at: filePath) {
            let currentContent = try fileManager.contents(at: filePath) ?? ""
            let needsNewline = !currentContent.isEmpty && !currentContent.hasSuffix("\n")
            let contentToAppend = needsNewline ? "\n" + content : content

            let fileHandle = try fileManager.fileHandleForWriting(to: filePath)
            defer { fileHandle.closeFile() }
            _ = fileHandle.seekToEndOfFile()
            guard let data = contentToAppend.data(using: .utf8) else {
                throw NSError(domain: "StringEncodingError", code: 1, userInfo: nil)
            }

            fileHandle.write(data)
        } else {
            try fileManager
                .writeStringToFile(
                    content: content,
                    path: filePath,
                    atomically: true,
                    encoding: .utf8,
                )
        }
    }
}
