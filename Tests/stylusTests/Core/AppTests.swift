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

    @Test func linkProcessorAndTagManagerWorkTogether() async {
        let mockMetadataProvider = MockMetadataProvider()
        await mockMetadataProvider.setMockTitle("Example Page", for: "https://example.com")

        let linkProcessor = LinkProcessor()
        let text = "Check out https://example.com for info"

        // Process the text through the link processor with mock provider
        let processedText = await linkProcessor.processLinks(in: text, metadataProvider: { mockMetadataProvider })
        let taggedText = addStylusInboxTag(to: processedText)

        // Verify that link processing and tag management work correctly together
        #expect(processedText == "Check out [Example Page](https://example.com) for info")
        #expect(taggedText == "Check out [Example Page](https://example.com) for info #stylus-inbox")
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
        #expect(writtenContent ==
            "- TODO **14:30** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_123.jpg)\n")
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

        try await app.handleImageMessage(
            fileId: "photo_456",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(mockBot.loadFileCallCount == 1)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == """
        - TODO **15:45** Beautiful sunset #stylus-inbox
        collapsed:: true
            - ![image](../assets/photo_456.png)

        """)
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

        try await app.handleImageMessage(
            fileId: "file_789",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/file_789"
        #expect(mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent ==
            "- TODO **16:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_789)\n")
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

        try await app.handleImageMessage(
            fileId: "animation",
            caption: "",
            timeString: timeString,
            filePath: testPath,
        )

        let writtenContent = try #require(mockFileWorker.fileSystem[testPath])
        #expect(writtenContent ==
            "- TODO **18:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/animation.gif)\n")
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

        try await app.handleImageMessage(
            fileId: "photo",
            caption: "New photo",
            timeString: timeString,
            filePath: testPath,
        )

        #expect(mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = try #require(String(
            data: mockFileWorker.mockFileHandle.data,
            encoding: .utf8,
        ))
        #expect(appendedContent ==
            "- TODO **19:00** New photo #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/photo.jpg)\n")
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
