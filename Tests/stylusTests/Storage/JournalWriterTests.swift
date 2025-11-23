import Foundation
@testable import stylus
import Testing

// MARK: - JournalWriterTests

@Suite("JournalWriterTests")
struct JournalWriterTests {
    @Test func ensureDirectoryExistsCreatesDirectory() throws {
        var createDirectoryCalled = false
        let fileWorker = MockFileWorker(
            fileExistsAtPath: { _ in false },
            createDirectoryAtPath: { _, _, _ in
                createDirectoryCalled = true
            },
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.ensureDirectoryExists(at: "/test/path")

        #expect(createDirectoryCalled)
    }

    @Test func ensureDirectoryExistsDoesNotCreateIfExists() throws {
        var createDirectoryCalled = false
        let fileWorker = MockFileWorker(
            fileExistsAtPath: { _ in true },
            createDirectoryAtPath: { _, _, _ in
                createDirectoryCalled = true
            },
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.ensureDirectoryExists(at: "/test/path")

        #expect(!createDirectoryCalled)
    }

    @Test func appendToJournalFileCreatesNewFile() throws {
        var writtenContent: String?
        let fileWorker = MockFileWorker(
            fileExistsAtPath: { _ in false },
            writeStringToFile: { content, _, _, _ in
                writtenContent = content
            },
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
        let fileWorker = MockFileWorker(
            fileExistsAtPath: { _ in true },
            contentsAtPath: { _ in "Existing content\n" },
            fileHandleForWritingToPath: { _ in mockFileHandle },
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.appendToJournalFile(at: "/test/file.md", content: "New content\n")

        let data = try #require(writtenData)
        let written = String(data: data, encoding: .utf8)
        #expect(written == "New content\n")
    }

    @Test func appendToJournalFileAddsNewlineIfNeeded() throws {
        var writtenData: Data?
        let mockFileHandle = MockFileHandle { data in
            writtenData = data
        }
        let fileWorker = MockFileWorker(
            fileExistsAtPath: { _ in true },
            contentsAtPath: { _ in "Existing content without newline" },
            fileHandleForWritingToPath: { _ in mockFileHandle },
        )
        let writer = JournalWriter(fileManager: fileWorker)

        try writer.appendToJournalFile(at: "/test/file.md", content: "New content\n")

        let data = try #require(writtenData)
        let written = String(data: data, encoding: .utf8)
        #expect(written == "\nNew content\n")
    }
}

// MARK: - MockFileWorker

final class MockFileWorker: FileWorker {
    // MARK: Properties

    private let _fileExistsAtPath: (String) -> Bool
    private let _createDirectoryAtPath: ((String, Bool, [FileAttributeKey: Any]?) throws -> Void)?
    private let _contentsAtPath: ((String) throws -> String?)?
    private let _writeStringToFile: ((String, String, Bool, String.Encoding) throws -> Void)?
    private let _fileHandleForWritingToPath: ((String) throws -> FileHandleProtocol)?

    // MARK: Lifecycle

    init(
        fileExistsAtPath: @escaping (String) -> Bool = { _ in false },
        createDirectoryAtPath: ((String, Bool, [FileAttributeKey: Any]?) throws -> Void)? = nil,
        contentsAtPath: ((String) throws -> String?)? = nil,
        writeStringToFile: ((String, String, Bool, String.Encoding) throws -> Void)? = nil,
        fileHandleForWritingToPath: ((String) throws -> FileHandleProtocol)? = nil,
    ) {
        _fileExistsAtPath = fileExistsAtPath
        _createDirectoryAtPath = createDirectoryAtPath
        _contentsAtPath = contentsAtPath
        _writeStringToFile = writeStringToFile
        _fileHandleForWritingToPath = fileHandleForWritingToPath
    }

    // MARK: Functions

    // MARK: FileWorker

    func homeDirectoryPath() -> String {
        "/home/mock"
    }

    func fileExists(at path: String) -> Bool {
        _fileExistsAtPath(path)
    }

    func createDirectory(at path: String, createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try _createDirectoryAtPath?(path, createIntermediates, attributes)
    }

    func contents(at path: String) throws -> String? {
        try _contentsAtPath?(path)
    }

    func writeStringToFile(content: String, path: String, atomically: Bool, encoding: String.Encoding) throws {
        try _writeStringToFile?(content, path, atomically, encoding)
    }

    func fileHandleForWriting(to path: String) throws -> FileHandleProtocol {
        guard let handler = _fileHandleForWritingToPath else {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No handler set"])
        }

        return try handler(path)
    }
}

// MARK: - MockFileHandle

final class MockFileHandle: FileHandleProtocol {
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
