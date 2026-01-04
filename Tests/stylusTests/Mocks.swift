import Foundation
@testable import stylus

// MARK: - MockFileHandle

final class MockFileHandle: FileHandleProtocol, @unchecked Sendable {
    // MARK: Properties

    var data = Data()
    var isClosed = false

    // MARK: Functions

    func seekToEndOfFile() -> UInt64 {
        UInt64(data.count)
    }

    func write(_ data: Data) {
        self.data.append(data)
    }

    func closeFile() {
        isClosed = true
    }
}

// MARK: - MockFileWorker

final class MockFileWorker: FileWorker, @unchecked Sendable {
    // MARK: Properties

    var fileSystem: [String: String] = [:]
    var directories: Set<String> = []
    var createDirectoryCallCount = 0
    var writeStringToFileCallCount = 0
    var fileHandleForWritingCallCount = 0
    let mockFileHandle = MockFileHandle()

    // MARK: Functions

    func homeDirectoryPath() -> String {
        "/mock/home"
    }

    func fileExists(at path: String) -> Bool {
        fileSystem[path] != nil || directories.contains(path)
    }

    func createDirectory(
        at path: String,
        createIntermediates _: Bool,
        attributes _: [FileAttributeKey: Any]?,
    ) throws {
        createDirectoryCallCount += 1
        directories.insert(path)
    }

    func contents(at path: String) throws -> String? {
        fileSystem[path]
    }

    func writeStringToFile(
        content: String,
        path: String,
        atomically _: Bool,
        encoding _: String.Encoding,
    ) throws {
        writeStringToFileCallCount += 1
        fileSystem[path] = content
    }

    func fileHandleForWriting(to _: String) throws -> FileHandleProtocol {
        fileHandleForWritingCallCount += 1
        return mockFileHandle
    }

    func writeDataToFile(
        data: Data,
        path: String,
    ) throws {
        // For testing purposes, we can store the data as a string representation
        // This allows us to verify the method was called correctly
        fileSystem[path] = "DATA_\(data.count)_BYTES"
    }

    func reset() {
        fileSystem = [:]
        directories = []
        createDirectoryCallCount = 0
        writeStringToFileCallCount = 0
        fileHandleForWritingCallCount = 0
        mockFileHandle.data = Data()
        mockFileHandle.isClosed = false
    }
}

// MARK: - MockBot

final class MockBot: Bot, @unchecked Sendable {
    // MARK: Properties

    var loadFileCallCount = 0
    var loadFileResult: (data: Data, filePath: String)?
    var loadFileError: Error?
    var respondAsSavedCallCount = 0

    // New properties for batch processing
    var fetchAllMessagesCallCount = 0
    var fetchAllMessagesResult: (messages: [Message], nextOffset: Int64?)?
    var fetchAllMessagesError: Error?

    // MARK: Functions

    func fetchAllMessages(startingOffset _: Int64?) async throws -> (messages: [Message], nextOffset: Int64?) {
        fetchAllMessagesCallCount += 1
        if let error = fetchAllMessagesError {
            throw error
        }
        return fetchAllMessagesResult ?? (messages: [], nextOffset: nil)
    }

    func respondAsSaved(on _: Message) {
        respondAsSavedCallCount += 1
    }

    func loadFile(with _: String) async throws -> (data: Data, filePath: String) {
        loadFileCallCount += 1
        if let error = loadFileError {
            throw error
        }
        guard let result = loadFileResult else {
            throw URLError(.badURL)
        }

        return result
    }

    func reset() {
        loadFileCallCount = 0
        loadFileResult = nil
        loadFileError = nil
        respondAsSavedCallCount = 0
        fetchAllMessagesCallCount = 0
        fetchAllMessagesResult = nil
        fetchAllMessagesError = nil
    }
}

// MARK: - MockLinkProcessor

actor MockLinkProcessor {
    // MARK: Properties

    private var processLinksResult: String?

    // MARK: Functions

    func setProcessLinksResult(_ result: String) {
        processLinksResult = result
    }

    func processLinks(in text: String) async -> String {
        processLinksResult ?? text
    }
}

// MARK: - MockMessageHandler

final class MockMessageHandler: MessageHandler, @unchecked Sendable {
    // MARK: Properties

    var handleJustTextMessageCallCount = 0
    var handleImageMessageCallCount = 0
    var handleDocumentMessageCallCount = 0
    var handleMessageTypeCallCount = 0
    var saveFileWithUniqueFilenameCallCount = 0

    var handleJustTextMessageError: Error?
    var handleImageMessageError: Error?
    var handleDocumentMessageError: Error?
    var saveFileWithUniqueFilenameError: Error?
    var saveFileWithUniqueFilenameResult: String?

    // MARK: Functions

    func handleJustTextMessage(
        text _: String, timeString _: String, filePath _: String, originalSender _: Message.From?,
    ) async throws {
        handleJustTextMessageCallCount += 1
        if let error = handleJustTextMessageError {
            throw error
        }
    }

    func handleImageMessage(
        fileId _: String,
        caption _: String?,
        timeString _: String,
        filePath _: String,
        originalSender _: Message.From?,
    ) async throws {
        handleImageMessageCallCount += 1
        if let error = handleImageMessageError {
            throw error
        }
    }

    func handleDocumentMessage(
        fileId _: String,
        fileName _: String?,
        caption _: String?,
        timeString _: String,
        filePath _: String,
        originalSender _: Message.From?,
    ) async throws {
        handleDocumentMessageCallCount += 1
        if let error = handleDocumentMessageError {
            throw error
        }
    }

    func handleMessageType(
        _: Message.MessageType,
        timeString _: String,
        filePath _: String,
        originalSender _: Message.From?,
    ) async {
        handleMessageTypeCallCount += 1
    }

    func saveFileWithUniqueFilename(data _: Data, baseFileName: String, assetsURL _: URL) async throws -> String {
        saveFileWithUniqueFilenameCallCount += 1
        if let error = saveFileWithUniqueFilenameError {
            throw error
        }
        return saveFileWithUniqueFilenameResult ?? baseFileName
    }

    func reset() {
        handleJustTextMessageCallCount = 0
        handleImageMessageCallCount = 0
        handleDocumentMessageCallCount = 0
        handleMessageTypeCallCount = 0
        saveFileWithUniqueFilenameCallCount = 0
        handleJustTextMessageError = nil
        handleImageMessageError = nil
        handleDocumentMessageError = nil
        saveFileWithUniqueFilenameError = nil
        saveFileWithUniqueFilenameResult = nil
    }
}
