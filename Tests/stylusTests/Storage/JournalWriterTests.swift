import Foundation
@testable import stylus
import Testing

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
