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
    var fetchPendingMessagesResult: (messages: [Message], nextOffset: Int64?)?
    var fetchPendingMessagesError: Error?

    // MARK: Functions

    func fetchPendingMessages(startingOffset: Int64?) async throws -> (messages: [Message], nextOffset: Int64?) {
        if let error = fetchPendingMessagesError {
            throw error
        }
        return fetchPendingMessagesResult ?? (messages: [], nextOffset: startingOffset)
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
        fetchPendingMessagesResult = nil
        fetchPendingMessagesError = nil
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
