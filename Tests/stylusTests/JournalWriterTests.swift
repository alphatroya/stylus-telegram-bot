import Foundation
@testable import stylus
import Testing

// MARK: - JournalWriterTests

@Suite("JournalWriterTests")
struct JournalWriterTests {
    @Test func ensureDirectoryExistsCreatesDirectory() throws {
        var createDirectoryCalled = false
        let fileWorker = FileWorker(
            fileExistsAtPath: { _ in false },
            createDirectoryAtPath: { _, _, _ in
                createDirectoryCalled = true
            }
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.ensureDirectoryExists(at: "/test/path")

        #expect(createDirectoryCalled)
    }

    @Test func ensureDirectoryExistsDoesNotCreateIfExists() throws {
        var createDirectoryCalled = false
        let fileWorker = FileWorker(
            fileExistsAtPath: { _ in true },
            createDirectoryAtPath: { _, _, _ in
                createDirectoryCalled = true
            }
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.ensureDirectoryExists(at: "/test/path")

        #expect(!createDirectoryCalled)
    }

    @Test func appendToJournalFileCreatesNewFile() throws {
        var writtenContent: String?
        let fileWorker = FileWorker(
            fileExistsAtPath: { _ in false },
            writeStringToFile: { content, _, _, _ in
                writtenContent = content
            }
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.appendToJournalFile(at: "/test/file.md", content: "Test content\n")

        #expect(writtenContent == "Test content\n")
    }

    @Test func appendToJournalFileAppendsToExisting() throws {
        var writtenData: Data?
        let mockFileHandle = MockFileHandle { data in
            writtenData = data
        }
        let fileWorker = FileWorker(
            fileExistsAtPath: { _ in true },
            contentsAtPath: { _ in "Existing content\n" },
            fileHandleForWritingToPath: { _ in mockFileHandle }
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.appendToJournalFile(at: "/test/file.md", content: "New content\n")

        guard let data = writtenData else {
            Issue.record("writtenData should not be nil")
            return
        }
        let written = String(data: data, encoding: .utf8)
        #expect(written == "New content\n")
    }

    @Test func appendToJournalFileAddsNewlineIfNeeded() throws {
        var writtenData: Data?
        let mockFileHandle = MockFileHandle { data in
            writtenData = data
        }
        let fileWorker = FileWorker(
            fileExistsAtPath: { _ in true },
            contentsAtPath: { _ in "Existing content without newline" },
            fileHandleForWritingToPath: { _ in mockFileHandle }
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.appendToJournalFile(at: "/test/file.md", content: "New content\n")

        guard let data = writtenData else {
            Issue.record("writtenData should not be nil")
            return
        }
        let written = String(data: data, encoding: .utf8)
        #expect(written == "\nNew content\n")
    }
}

// MARK: - MockFileHandle

class MockFileHandle: FileHandleProtocol {
    // MARK: Properties

    private let writeCallback: (Data) -> Void

    // MARK: Lifecycle

    init(writeCallback: @escaping (Data) -> Void) {
        self.writeCallback = writeCallback
    }

    // MARK: Functions

    func seekToEndOfFile() -> UInt64 { 0 }

    func write(_ data: Data) {
        writeCallback(data)
    }

    func closeFile() {}
}
