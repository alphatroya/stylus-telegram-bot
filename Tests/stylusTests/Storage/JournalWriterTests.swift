import Foundation
@testable import stylus
import Testing

// MARK: - JournalWriterTests

@Suite("JournalWriterTests")
struct JournalWriterTests {
    @Test func `ensure directory exists creates directory`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/directory"

        try await journalWriter.ensureDirectoryExists(at: testPath)

        #expect(mockFileWorker.createDirectoryCallCount == 1)
        #expect(mockFileWorker.directories.contains(testPath))
    }

    @Test func `ensure directory exists does not create if exists`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/existing/directory"

        // Simulate existing directory
        mockFileWorker.directories.insert(testPath)

        try await journalWriter.ensureDirectoryExists(at: testPath)

        #expect(mockFileWorker.createDirectoryCallCount == 0)
    }

    @Test func `append to journal file creates new file`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.txt"
        let content = "New journal entry"

        try await journalWriter.appendToJournalFile(at: testPath, content: content)

        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        #expect(mockFileWorker.fileSystem[testPath] == content)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 0)
    }

    @Test func `append to journal file appends to existing`() async throws {
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

    @Test func `append to journal file adds newline if needed`() async throws {
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

    @Test func `append to journal file does not add newline when not needed`() async throws {
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

    @Test func `append to journal file handles empty existing file`() async throws {
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

    @Test func `save image file saves when file does not exist`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/image.jpg"
        let testData = Data([0xFF, 0xD8, 0xFF]) // JPEG header bytes

        try await journalWriter.saveImageFile(data: testData, to: testPath)

        #expect(mockFileWorker.fileSystem[testPath] == "DATA_3_BYTES")
    }

    @Test func `save image file throws when file exists`() async throws {
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

    // MARK: - Duplicate Detection Tests

    @Test func `single duplicate detected and skipped`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.md"
        let entry = "- **14:30** [Title](url) #from-readeck #stylus-inbox\n"

        // First write: file doesn't exist, creates it
        try await journalWriter.appendToJournalFile(at: testPath, content: entry)
        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        #expect(mockFileWorker.fileSystem[testPath] == entry)

        // Second write: same content, should be skipped
        try await journalWriter.appendToJournalFile(at: testPath, content: entry)
        #expect(mockFileWorker.writeStringToFileCallCount == 1) // still 1, no new write
        #expect(mockFileWorker.fileHandleForWritingCallCount == 0) // no append either
        #expect(mockFileWorker.fileSystem[testPath] == entry) // content unchanged
    }

    @Test func `non-duplicate entry appended normally`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.md"
        let entry1 = "- **09:00** First entry\n"
        let entry2 = "- **10:30** Second entry\n"

        mockFileWorker.fileSystem[testPath] = entry1

        try await journalWriter.appendToJournalFile(at: testPath, content: entry2)

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == entry2)
    }

    @Test func `file does not exist creates without dedup`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/new_journal.md"
        let content = "First ever entry\n"

        // File doesn't exist — should create it without any dedup check
        try await journalWriter.appendToJournalFile(at: testPath, content: content)

        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        #expect(mockFileWorker.fileSystem[testPath] == content)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 0)
    }

    @Test func `empty existing file appends without dedup`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/empty_journal.md"
        let content = "First entry in empty file\n"

        // Simulate empty existing file
        mockFileWorker.fileSystem[testPath] = ""

        try await journalWriter.appendToJournalFile(at: testPath, content: content)

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == content)
    }

    @Test func `batch with some duplicates only appends new`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.md"
        let entry1 = "- **09:00** First\n"
        let entry2 = "- **10:00** Second\n"
        let entry3 = "- **11:00** Third\n"

        // File already has entry1 and entry2
        mockFileWorker.fileSystem[testPath] = entry1 + entry2

        // Batch: entry1 (dup), entry2 (dup), entry3 (new)
        try await journalWriter.appendToJournalFile(at: testPath, contents: [entry1, entry2, entry3])

        // entry3 should be appended via the content method
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        #expect(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8) == entry3)
    }

    @Test func `batch with all duplicates does not modify file`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.md"
        let entry1 = "- **09:00** First\n"
        let entry2 = "- **10:00** Second\n"

        let originalContent = entry1 + entry2
        mockFileWorker.fileSystem[testPath] = originalContent

        // Batch: all entries already exist
        try await journalWriter.appendToJournalFile(at: testPath, contents: [entry1, entry2])

        #expect(mockFileWorker.writeStringToFileCallCount == 0)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 0)
        #expect(mockFileWorker.fileSystem[testPath] == originalContent) // unchanged
    }

    @Test func `batch with no duplicates appends all`() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let testPath = "/test/journal.md"
        let entry1 = "- **09:00** First\n"
        let entry2 = "- **10:00** Second\n"
        let entry3 = "- **11:00** Third\n"

        // File already has entry1
        mockFileWorker.fileSystem[testPath] = entry1

        // Batch: entry2 and entry3 are new
        try await journalWriter.appendToJournalFile(at: testPath, contents: [entry2, entry3])

        // Both new entries should be appended via the content method (combined)
        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appended = String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8)
        #expect(appended == entry2 + entry3)
    }
}
