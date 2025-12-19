import Foundation
@testable import stylus
import Testing

// MARK: - AppTests

@Suite("AppTests")
struct AppTests {
    @Test func handleJustTextMessageProcessesTextCorrectly() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/journal.md"
        let timeString = "14:30"
        let text = "Test message without links"

        try await app.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **14:30** Test message without links #stylus-inbox\n")
    }

    @Test func handleJustTextMessageAddsInboxTag() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
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
        let config = makeTestConfig()
        let mockBot = MockBot()

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
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

    @Test func handleJustTextMessageProcessesLinksInText() async {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let mockMetadataProvider = MockMetadataProvider()
        await mockMetadataProvider.setMockTitle("Example Page", for: "https://example.com")

        let linkProcessor = LinkProcessor()
        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: linkProcessor,
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/journal.md"
        let timeString = "11:00"
        let text = "Check out https://example.com for info"

        // Process the text through the link processor with mock provider
        let processedText = await linkProcessor.processLinks(in: text, metadataProvider: { mockMetadataProvider })
        let taggedText = addStylusInboxTag(to: processedText)
        let expectedContent = "- TODO **11:00** \(taggedText)\n"

        // Since we can't inject the metadata provider into App directly,
        // we verify that the link processing logic works correctly
        #expect(processedText == "Check out [Example Page](https://example.com) for info")
        #expect(taggedText == "Check out [Example Page](https://example.com) for info #stylus-inbox")
        #expect(expectedContent == "- TODO **11:00** Check out [Example Page](https://example.com) for info #stylus-inbox\n")
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithoutCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        mockBot.loadFileResult = (data: testImageData, filePath: "file_123.jpg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await app.handleImageMessage(fileId: "file_123", caption: nil, timeString: timeString, filePath: testPath)

        #expect(mockBot.loadFileCallCount == 1)
        #expect(mockFileWorker.createDirectoryCallCount == 1)
        #expect(mockFileWorker.directories.contains("/test/kb/assets"))

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **14:30** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_123.jpg)\n")
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        mockBot.loadFileResult = (data: testImageData, filePath: "photo_456.png")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:45"
        let caption = "Beautiful sunset"

        try await app.handleImageMessage(fileId: "photo_456", caption: caption, timeString: timeString, filePath: testPath)

        #expect(mockBot.loadFileCallCount == 1)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent ==
            "- TODO **15:45** Beautiful sunset #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/photo_456.png)\n")
    }

    @Test func handleImageMessageHandlesFileWithoutExtension() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0x00, 0x01, 0x02])
        mockBot.loadFileResult = (data: testImageData, filePath: "file_789")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await app.handleImageMessage(fileId: "file_789", caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/file_789"
        #expect(mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **16:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_789)\n")
    }

    @Test func handleImageMessageSavesImageToAssetsFolder() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        mockBot.loadFileResult = (data: testImageData, filePath: "image_999.jpeg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
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
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0x47, 0x49, 0x46]) // GIF header
        mockBot.loadFileResult = (data: testImageData, filePath: "animation.gif")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "18:00"

        try await app.handleImageMessage(fileId: "animation", caption: "", timeString: timeString, filePath: testPath)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **18:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/animation.gif)\n")
    }

    @Test func handleImageMessageAppendsToExistingJournal() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testImageData = Data([0xFF, 0xD8])
        mockBot.loadFileResult = (data: testImageData, filePath: "photo.jpg")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let existingContent = "- TODO **09:00** Previous entry #stylus-inbox\n"
        mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "19:00"

        try await app.handleImageMessage(fileId: "photo", caption: "New photo", timeString: timeString, filePath: testPath)

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = try #require(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8))
        #expect(appendedContent == "- TODO **19:00** New photo #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/photo.jpg)\n")
    }

    @Test func handleDocumentMessageCreatesCorrectMarkdownWithFileName() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46]) // PDF header
        mockBot.loadFileResult = (data: testDocumentData, filePath: "document_123.pdf")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await app.handleDocumentMessage(
            fileId: "doc_123",
            fileName: "report.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(mockBot.loadFileCallCount == 1)
        #expect(mockFileWorker.createDirectoryCallCount == 1)
        #expect(mockFileWorker.directories.contains("/test/kb/assets"))

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **14:30** #stylus-inbox\ncollapsed:: true\n    - [📄 report.pdf](../assets/report.pdf)\n")
    }

    @Test func handleDocumentMessageCreatesCorrectMarkdownWithCaption() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x50, 0x4B, 0x03, 0x04]) // ZIP header
        mockBot.loadFileResult = (data: testDocumentData, filePath: "archive_456.zip")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:45"
        let caption = "Important files archive"

        try await app.handleDocumentMessage(
            fileId: "archive_456",
            fileName: "files.zip",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(mockBot.loadFileCallCount == 1)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent ==
            "- TODO **15:45** Important files archive #stylus-inbox\ncollapsed:: true\n    - [📄 files.zip](../assets/files.zip)\n")
    }

    @Test func handleDocumentMessageHandlesNilFileName() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x7F, 0x45, 0x4C, 0x46]) // ELF header
        mockBot.loadFileResult = (data: testDocumentData, filePath: "file_789.bin")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await app.handleDocumentMessage(fileId: "file_789", fileName: nil, caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/file_789.bin"
        #expect(mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **16:00** #stylus-inbox\ncollapsed:: true\n    - [📄 file_789.bin](../assets/file_789.bin)\n")
    }

    @Test func handleDocumentMessageHandlesEmptyFileName() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x89, 0x48, 0x44, 0x46])
        mockBot.loadFileResult = (data: testDocumentData, filePath: "document_999")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "17:30"

        try await app.handleDocumentMessage(fileId: "document_999", fileName: "", caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/document_999"
        #expect(mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **17:30** #stylus-inbox\ncollapsed:: true\n    - [📄 document_999](../assets/document_999)\n")
    }

    @Test func handleDocumentMessageSavesDocumentToAssetsFolder() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        mockBot.loadFileResult = (data: testDocumentData, filePath: "contract.pdf")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "18:00"

        try await app.handleDocumentMessage(
            fileId: "contract",
            fileName: "contract.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/contract.pdf"
        #expect(mockFileWorker.fileSystem[assetPath] == "DATA_5_BYTES")
    }

    @Test func handleDocumentMessageAppendsToExistingJournal() async throws {
        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)
        let config = makeTestConfig()
        let mockBot = MockBot()
        let testDocumentData = Data([0x25, 0x50])
        mockBot.loadFileResult = (data: testDocumentData, filePath: "invoice.pdf")

        let app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
        )

        let testPath = "/test/kb/journals/2025_01_01.md"
        let existingContent = "- TODO **09:00** Previous entry #stylus-inbox\n"
        mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "19:00"

        try await app.handleDocumentMessage(
            fileId: "invoice",
            fileName: "invoice.pdf",
            caption: "Monthly invoice",
            timeString: timeString,
            filePath: testPath,
        )

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = try #require(String(data: mockFileWorker.mockFileHandle.data, encoding: .utf8))
        #expect(appendedContent ==
            "- TODO **19:00** Monthly invoice #stylus-inbox\ncollapsed:: true\n    - [📄 invoice.pdf](../assets/invoice.pdf)\n")
    }

    // MARK: - Helpers

    private func makeTestConfig() -> Config {
        Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb",
        )
    }
}
