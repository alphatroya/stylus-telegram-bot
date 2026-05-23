import Foundation

// MARK: - ImageFileError

public enum ImageFileError: Error, LocalizedError, Equatable {
    case fileAlreadyExists(String)

    // MARK: Computed Properties

    public var errorDescription: String? {
        switch self {
        case let .fileAlreadyExists(filePath):
            "Image file already exists at path: \(filePath)"
        }
    }
}

// MARK: - JournalWriter

actor JournalWriter {
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
        if try containsDuplicate(at: filePath, content: content) {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            print("🔁 Skipped duplicate entry in \(fileName)")
            return
        }

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

    func appendToJournalFile(at filePath: String, contents: [String]) throws {
        guard !contents.isEmpty else { return }

        // Read existing lines once for batch dedup
        var existingTrimmedLines: Set<String> = []
        if fileManager.fileExists(at: filePath) {
            if let currentContent = try fileManager.contents(at: filePath), !currentContent.isEmpty {
                existingTrimmedLines = Set(
                    currentContent.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty },
                )
            }
        }

        let newEntries = contents.filter { entry in
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            return !existingTrimmedLines.contains(trimmed)
        }

        let skippedCount = contents.count - newEntries.count
        if skippedCount > 0 {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            print("🔁 Skipped \(skippedCount) duplicate entry(ies) in \(fileName)")
        }

        guard !newEntries.isEmpty else { return }

        let combined = newEntries.joined()
        try appendToJournalFile(at: filePath, content: combined)
    }

    func saveImageFile(data: Data, to filePath: String) throws {
        guard !fileManager.fileExists(at: filePath) else {
            throw ImageFileError.fileAlreadyExists(filePath)
        }

        try fileManager.writeDataToFile(data: data, path: filePath)
    }

    // MARK: Private Functions

    private func containsDuplicate(at filePath: String, content: String) throws -> Bool {
        guard fileManager.fileExists(at: filePath) else { return false }

        let currentContent = try fileManager.contents(at: filePath) ?? ""
        guard !currentContent.isEmpty else { return false }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingLines = currentContent.components(separatedBy: .newlines)
        return existingLines.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedContent }
    }
}
