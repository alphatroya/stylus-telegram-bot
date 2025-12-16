import Foundation
@testable import stylus
import Testing

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

// MARK: - JournalWriterTests

@Suite("JournalWriterTests")
struct JournalWriterTests {
    @Test func ensureDirectoryExistsCreatesDirectory() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/directory"

        try await journalWriter.ensureDirectoryExists(at: testPath)

        #expect(mockFileWorker.createDirectoryCallCount == 1)
        #expect(mockFileWorker.directories.contains(testPath))
    }

    @Test func ensureDirectoryExistsDoesNotCreateIfExists() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/existing/directory"

        // Simulate existing directory
        mockFileWorker.directories.insert(testPath)

        try await journalWriter.ensureDirectoryExists(at: testPath)

        #expect(mockFileWorker.createDirectoryCallCount == 0)
    }

    @Test func appendToJournalFileCreatesNewFile() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let content = "New journal entry"

        try await journalWriter.appendToJournalFile(at: testPath, content: content)

        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        #expect(mockFileWorker.fileSystem[testPath] == content)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 0)
    }

    @Test func appendToJournalFileAppendsToExisting() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let existingContent = "Existing content\n"
        let newContent = "New entry"

        // Simulate existing file
        mockFileWorker.fileSystem[testPath] = existingContent

        try await journalWriter.appendToJournalFile(at: testPath, content: newContent)

        #expect(mockFileWorker.writeStringToFileCallCount == 0)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == newContent)
        #expect(mockFileWorker.mockFileHandle.isClosed == true)
    }

    @Test func appendToJournalFileAddsNewlineIfNeeded() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let existingContent = "Content without newline"
        let newContent = "New entry"

        // Simulate existing file without trailing newline
        mockFileWorker.fileSystem[testPath] = existingContent

        try await journalWriter.appendToJournalFile(at: testPath, content: newContent)

        #expect(mockFileWorker.writeStringToFileCallCount == 0)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == "\n" + newContent)
        #expect(mockFileWorker.mockFileHandle.isClosed == true)
    }

    @Test func appendToJournalFileDoesNotAddNewlineWhenNotNeeded() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let existingContent = "Content with newline\n"
        let newContent = "New entry"

        // Simulate existing file with trailing newline
        mockFileWorker.fileSystem[testPath] = existingContent

        try await journalWriter.appendToJournalFile(at: testPath, content: newContent)

        #expect(mockFileWorker.writeStringToFileCallCount == 0)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == newContent)
        #expect(mockFileWorker.mockFileHandle.isClosed == true)
    }

    @Test func appendToJournalFileHandlesEmptyExistingFile() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let newContent = "First entry"

        // Simulate empty existing file
        mockFileWorker.fileSystem[testPath] = ""

        try await journalWriter.appendToJournalFile(at: testPath, content: newContent)

        #expect(mockFileWorker.writeStringToFileCallCount == 0)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == newContent)
        #expect(mockFileWorker.mockFileHandle.isClosed == true)
    }

    @Test func saveImageFileSavesWhenFileDoesNotExist() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/image.jpg"
        let testData = Data([0xFF, 0xD8, 0xFF]) // JPEG header bytes

        try await journalWriter.saveImageFile(data: testData, to: testPath)

        #expect(mockFileWorker.fileSystem[testPath] == "DATA_3_BYTES")
    }

    @Test func saveImageFileThrowsWhenFileExists() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/existing.jpg"
        let testData = Data([0xFF, 0xD8, 0xFF])

        // Simulate existing file
        mockFileWorker.fileSystem[testPath] = "existing content"

        await #expect(throws: ImageFileError.fileAlreadyExists(testPath)) {
            try await journalWriter.saveImageFile(data: testData, to: testPath)
        }
    }
}
