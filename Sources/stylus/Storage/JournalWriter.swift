import Foundation

// MARK: - JournalWriter

struct JournalWriter {
    // MARK: Properties

    let fileManager: FileWorker

    // MARK: Lifecycle

    init(fileManager: FileWorker = .system) {
        self.fileManager = fileManager
    }

    // MARK: Functions

    func ensureDirectoryExists(at path: String) throws {
        if !fileManager.fileExistsAtPath(path) {
            try fileManager.createDirectoryAtPath(path, true, nil)
        }
    }

    func appendToJournalFile(at filePath: String, content: String) throws {
        if fileManager.fileExistsAtPath(filePath) {
            let currentContent = try fileManager.contentsAtPath(filePath) ?? ""
            let needsNewline = !currentContent.isEmpty && !currentContent.hasSuffix("\n")
            let contentToAppend = needsNewline ? "\n" + content : content

            let fileHandle = try fileManager.fileHandleForWritingToPath(filePath)
            _ = fileHandle.seekToEndOfFile()
            guard let data = contentToAppend.data(using: .utf8) else {
                throw NSError(domain: "StringEncodingError", code: 1, userInfo: nil)
            }

            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try fileManager.writeStringToFile(content, filePath, true, .utf8)
        }
    }
}
