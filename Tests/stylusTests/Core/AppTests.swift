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

// MARK: - MockBot

final class MockBot: Bot, @unchecked Sendable {
    // MARK: Properties

    var loadFileCallCount = 0
    var loadFileResult: (data: Data, filePath: String)?
    var loadFileError: Error?
    var respondAsSavedCallCount = 0

    // MARK: Functions

    func launch() -> AsyncThrowingStream<Message, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
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

// MARK: - AppTests

@Suite("AppTests")
struct AppTests {
    @Test func handleJustTextMessageProcessesTextCorrectly() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let mockLinkProcessor = MockLinkProcessor()
        await mockLinkProcessor.setProcessLinksResult("Processed text with [link](https://example.com)")

        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()

        // Create a custom LinkProcessor wrapper that uses our mock
        let linkProcessor = LinkProcessor()
        var app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: linkProcessor,
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/journal.md"
        let timeString = "14:30"
        let text = "Test message with https://example.com"

        // Since we can't directly inject MockLinkProcessor, we'll test with the real one
        // but verify the output format is correct
        try await app.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent != nil)
        #expect(writtenContent!.contains("- TODO **14:30**"))
        #expect(writtenContent!.contains("#stylus-inbox"))
        #expect(writtenContent!.hasSuffix("\n"))
    }

    @Test func handleJustTextMessageAddsInboxTag() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/journal.md"
        let timeString = "10:15"
        let text = "Simple message"

        try await app.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent == "- TODO **10:15** Simple message #stylus-inbox\n")
    }

    @Test func handleJustTextMessageAppendsToExistingFile() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/journal.md"
        let existingContent = "- TODO **09:00** First entry #stylus-inbox\n"
        mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "10:15"
        let text = "Second message"

        try await app.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8)
        #expect(appendedContent == "- TODO **10:15** Second message #stylus-inbox\n")
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithoutCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        mockBot.loadFileResult = (data: testImageData, filePath: "file_123.jpg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await app.handleImageMessage(fileId: "file_123", caption: nil, timeString: timeString, filePath: testPath)

        #expect(mockBot.loadFileCallCount == 1)
        #expect(mockFileWorker.createDirectoryCallCount == 1)
        #expect(mockFileWorker.directories.contains("/test/kb/assets"))

        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent != nil)
        #expect(writtenContent!.contains("- TODO **14:30** #stylus-inbox"))
        #expect(writtenContent!.contains("collapsed:: true"))
        #expect(writtenContent!.contains("![image](../assets/file_123.jpg)"))
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        mockBot.loadFileResult = (data: testImageData, filePath: "photo_456.png")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:45"
        let caption = "Beautiful sunset"

        try await app.handleImageMessage(fileId: "photo_456", caption: caption, timeString: timeString, filePath: testPath)

        #expect(mockBot.loadFileCallCount == 1)

        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent != nil)
        #expect(writtenContent!.contains("- TODO **15:45** Beautiful sunset #stylus-inbox"))
        #expect(writtenContent!.contains("collapsed:: true"))
        #expect(writtenContent!.contains("![image](../assets/photo_456.png)"))
    }

    @Test func handleImageMessageHandlesFileWithoutExtension() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0x00, 0x01, 0x02])
        mockBot.loadFileResult = (data: testImageData, filePath: "file_789")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await app.handleImageMessage(fileId: "file_789", caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/file_789"
        #expect(mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent != nil)
        #expect(writtenContent!.contains("![image](../assets/file_789)"))
    }

    @Test func handleImageMessageSavesImageToAssetsFolder() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        mockBot.loadFileResult = (data: testImageData, filePath: "image_999.jpeg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "17:30"

        try await app.handleImageMessage(fileId: "image_999", caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/image_999.jpeg"
        #expect(mockFileWorker.fileSystem[assetPath] == "DATA_4_BYTES")
    }

    @Test func handleImageMessageAddsInboxTagToEmptyCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0x47, 0x49, 0x46]) // GIF header
        mockBot.loadFileResult = (data: testImageData, filePath: "animation.gif")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "18:00"

        try await app.handleImageMessage(fileId: "animation", caption: "", timeString: timeString, filePath: testPath)

        let writtenContent = mockFileWorker.fileSystem[testPath]
        #expect(writtenContent != nil)
        // Empty caption should still have the tag directly after time
        #expect(writtenContent!.contains("- TODO **18:00** #stylus-inbox"))
    }

    @Test func handleImageMessageAppendsToExistingJournal() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb"
        )
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8])
        mockBot.loadFileResult = (data: testImageData, filePath: "photo.jpg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let existingContent = "- TODO **09:00** Previous entry #stylus-inbox\n"
        mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "19:00"

        try await app.handleImageMessage(fileId: "photo", caption: "New photo", timeString: timeString, filePath: testPath)

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8)
        #expect(appendedContent != nil)
        #expect(appendedContent!.contains("- TODO **19:00** New photo #stylus-inbox"))
        #expect(appendedContent!.contains("collapsed:: true"))
    }
}
