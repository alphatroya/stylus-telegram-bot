import Foundation
@testable import stylus
import Testing

// MARK: - MessageHandlerTestContext

struct MessageHandlerTestContext {
    // MARK: Properties

    let mockFileWorker: MockFileWorker
    let journalWriter: JournalWriter
    let config: Config
    let mockBot: MockBot
    let linkProcessor: LinkProcessor
    let messageHandler: DefaultMessageHandler

    // MARK: Lifecycle

    init() {
        mockFileWorker = MockFileWorker()
        journalWriter = JournalWriter(fileManager: mockFileWorker)
        config = Config(
            telegramBotApiKey: SecretString("test-key"),
            telegramUserID: 123,
            knowledgeBaseLocation: "/test/kb",
        )
        mockBot = MockBot()
        linkProcessor = LinkProcessor()
        messageHandler = DefaultMessageHandler(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: linkProcessor,
            bot: mockBot,
        )
    }
}

// MARK: - MessageHandlerTests

@Suite("MessageHandlerTests")
struct MessageHandlerTests {
    @Test func handleJustTextMessageProcessesTextCorrectly() async throws {
        let context = MessageHandlerTestContext()

        let testPath = "/test/journal.md"
        let timeString = "14:30"
        let text = "Test message without links"

        try await context.messageHandler.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        #expect(context.mockFileWorker.writeStringToFileCallCount == 1)
        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **14:30** Test message without links #stylus-inbox\n")
    }

    @Test func handleJustTextMessageAddsInboxTag() async throws {
        let context = MessageHandlerTestContext()

        let testPath = "/test/journal.md"
        let timeString = "10:15"
        let text = "Simple message"

        try await context.messageHandler.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        let writtenContent = context.mockFileWorker.fileSystem[testPath]
        #expect(writtenContent == "- TODO **10:15** Simple message #stylus-inbox\n")
    }

    @Test func handleJustTextMessageAppendsToExistingFile() async throws {
        let context = MessageHandlerTestContext()

        let testPath = "/test/journal.md"
        let existingContent = "- TODO **09:00** First entry #stylus-inbox\n"
        context.mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "10:15"
        let text = "Second message"

        try await context.messageHandler.handleJustTextMessage(text: text, timeString: timeString, filePath: testPath)

        #expect(context.mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = String(data: context.mockFileWorker.mockFileHandle.data, encoding: .utf8)
        #expect(appendedContent == "- TODO **10:15** Second message #stylus-inbox\n")
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithoutCaption() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        context.mockBot.loadFileResult = (data: testImageData, filePath: "file_123.jpg")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await context.messageHandler.handleImageMessage(fileId: "file_123", caption: nil, timeString: timeString, filePath: testPath)

        #expect(context.mockBot.loadFileCallCount == 1)
        #expect(context.mockFileWorker.createDirectoryCallCount == 1)
        #expect(context.mockFileWorker.directories.contains("/test/kb/assets"))

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **14:30** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_123.jpg)\n",
        )
    }

    @Test func handleImageMessageCreatesCorrectMarkdownWithCaption() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        context.mockBot.loadFileResult = (data: testImageData, filePath: "photo_456.png")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:45"
        let caption = "Beautiful sunset"

        try await context.messageHandler.handleImageMessage(
            fileId: "photo_456",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(context.mockBot.loadFileCallCount == 1)

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == """
        - TODO **15:45** Beautiful sunset #stylus-inbox
        collapsed:: true
            - ![image](../assets/photo_456.png)

        """)
    }

    @Test func handleImageMessageHandlesFileWithoutExtension() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0x00, 0x01, 0x02])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "file_789")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await context.messageHandler.handleImageMessage(
            fileId: "file_789",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/file_789"
        #expect(context.mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **16:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/file_789)\n",
        )
    }

    @Test func handleImageMessageSavesImageToAssetsFolder() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "image_999.jpeg")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "17:30"

        try await context.messageHandler.handleImageMessage(fileId: "image_999", caption: nil, timeString: timeString, filePath: testPath)

        let assetPath = "/test/kb/assets/image_999.jpeg"
        #expect(context.mockFileWorker.fileSystem[assetPath] == "DATA_4_BYTES")
    }

    @Test func handleImageMessageAddsInboxTagToEmptyCaption() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0x47, 0x49, 0x46]) // GIF header
        context.mockBot.loadFileResult = (data: testImageData, filePath: "animation.gif")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "18:00"

        try await context.messageHandler.handleImageMessage(
            fileId: "animation",
            caption: "",
            timeString: timeString,
            filePath: testPath,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **18:00** #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/animation.gif)\n",
        )
    }

    @Test func handleImageMessageAppendsToExistingJournal() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "photo.jpg")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let existingContent = "- TODO **09:00** Previous entry #stylus-inbox\n"
        context.mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "19:00"

        try await context.messageHandler.handleImageMessage(
            fileId: "photo",
            caption: "New photo",
            timeString: timeString,
            filePath: testPath,
        )

        #expect(context.mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = try #require(String(
            data: context.mockFileWorker.mockFileHandle.data,
            encoding: .utf8,
        ))
        #expect(
            appendedContent ==
                "- TODO **19:00** New photo #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/photo.jpg)\n",
        )
    }

    @Test func handleDocumentMessageCreatesCorrectMarkdownWithFileName() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46]) // PDF header
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "document_123.pdf")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "doc_123",
            fileName: "report.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(context.mockBot.loadFileCallCount == 1)
        #expect(context.mockFileWorker.createDirectoryCallCount == 1)
        #expect(context.mockFileWorker.directories.contains("/test/kb/assets"))

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **14:30** #stylus-inbox\ncollapsed:: true\n    - ![report.pdf](../assets/report.pdf)\n",
        )
    }

    @Test func handleDocumentMessageCreatesCorrectMarkdownWithCaption() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x50, 0x4B, 0x03, 0x04]) // ZIP header
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "archive_456.zip")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:45"
        let caption = "Important files archive"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "archive_456",
            fileName: "files.zip",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
        )

        #expect(context.mockBot.loadFileCallCount == 1)

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **15:45** Important files archive #stylus-inbox\ncollapsed:: true\n" +
                "    - [files.zip](../assets/files.zip)\n",
        )
    }

    @Test func handleDocumentMessageHandlesNilFileName() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x7F, 0x45, 0x4C, 0x46]) // ELF header
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "file_789.bin")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "file_789",
            fileName: nil,
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/file_789.bin"
        #expect(context.mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **16:00** #stylus-inbox\ncollapsed:: true\n    - [file_789.bin](../assets/file_789.bin)\n",
        )
    }

    @Test func handleDocumentMessageHandlesEmptyFileName() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x89, 0x48, 0x44, 0x46])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "document_999")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "17:30"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "document_999",
            fileName: "",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/document_999"
        #expect(context.mockFileWorker.fileSystem[assetPath] != nil)

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **17:30** #stylus-inbox\ncollapsed:: true\n    - [document_999](../assets/document_999)\n",
        )
    }

    @Test func handleDocumentMessageSavesDocumentToAssetsFolder() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "contract.pdf")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "18:00"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "contract",
            fileName: "contract.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        let assetPath = "/test/kb/assets/contract.pdf"
        #expect(context.mockFileWorker.fileSystem[assetPath] == "DATA_5_BYTES")
    }

    @Test func handleDocumentMessageAppendsToExistingJournal() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "invoice.pdf")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let existingContent = "- TODO **09:00** Previous entry #stylus-inbox\n"
        context.mockFileWorker.fileSystem[testPath] = existingContent

        let timeString = "19:00"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "invoice",
            fileName: "invoice.pdf",
            caption: "Monthly invoice",
            timeString: timeString,
            filePath: testPath,
        )

        #expect(context.mockFileWorker.fileHandleForWritingCallCount == 1)
        let appendedContent = try #require(String(data: context.mockFileWorker.mockFileHandle.data, encoding: .utf8))
        #expect(
            appendedContent ==
                "- TODO **19:00** Monthly invoice #stylus-inbox\ncollapsed:: true\n" +
                "    - ![invoice.pdf](../assets/invoice.pdf)\n",
        )
    }

    @Test func handleDocumentMessageAppendsRandomSuffixWhenFilenameExists() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "report.pdf")

        // Pre-create the file to simulate it already exists
        context.mockFileWorker.fileSystem["/test/kb/assets/report.pdf"] = "existing file"

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "doc_123",
            fileName: "report.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify that the new file was saved with a different name
        let assetKeys = context.mockFileWorker.fileSystem.keys.filter { $0.hasPrefix("/test/kb/assets/report_") }
        #expect(assetKeys.count == 1)

        // Verify the new filename has the pattern report_XXXXXXXX.pdf
        let newAssetPath = try #require(assetKeys.first)
        let newFileName = URL(fileURLWithPath: newAssetPath).lastPathComponent
        #expect(newFileName.hasPrefix("report_"))
        #expect(newFileName.hasSuffix(".pdf"))
        #expect(newFileName.count > "report_.pdf".count) // Has random suffix

        // Verify the journal entry uses the new filename
        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent.contains("![\(newFileName)](../assets/\(newFileName))"))
    }

    @Test func handleImageMessageAppendsRandomSuffixWhenFilenameExists() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8, 0xFF])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "photo_123.jpg")

        // Pre-create the file to simulate it already exists
        context.mockFileWorker.fileSystem["/test/kb/assets/photo_123.jpg"] = "existing file"

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:00"

        try await context.messageHandler.handleImageMessage(fileId: "photo_123", caption: nil, timeString: timeString, filePath: testPath)

        // Verify that the new file was saved with a different name
        let assetKeys = context.mockFileWorker.fileSystem.keys.filter { $0.hasPrefix("/test/kb/assets/photo_123_") }
        #expect(assetKeys.count == 1)

        // Verify the new filename has the pattern photo_123_XXXXXXXX.jpg
        let newAssetPath = try #require(assetKeys.first)
        let newFileName = URL(fileURLWithPath: newAssetPath).lastPathComponent
        #expect(newFileName.hasPrefix("photo_123_"))
        #expect(newFileName.hasSuffix(".jpg"))
        #expect(newFileName.count > "photo_123_.jpg".count) // Has random suffix

        // Verify the journal entry uses the new filename
        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent.contains("![image](../assets/\(newFileName))"))
    }

    @Test func handleDocumentMessageWithMultipleCollisionsEventuallySucceeds() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "data.txt")

        // Pre-create the file to simulate it already exists
        context.mockFileWorker.fileSystem["/test/kb/assets/data.txt"] = "existing file"

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:00"

        try await context.messageHandler.handleDocumentMessage(
            fileId: "data_file",
            fileName: "data.txt",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify that a file with a unique name was created
        let assetKeys = context.mockFileWorker.fileSystem.keys.filter {
            $0.hasPrefix("/test/kb/assets/data_") && $0.hasSuffix(".txt")
        }
        #expect(assetKeys.count == 1)

        // Original file should still exist
        #expect(context.mockFileWorker.fileSystem["/test/kb/assets/data.txt"] == "existing file")
    }

    @Test func handleDocumentMessageSanitizesPathTraversalInFileName() async throws {
        let context = MessageHandlerTestContext()
        context.mockBot.loadFileResult = (data: Data("test document".utf8), filePath: "file_path_info.pdf")

        let testPath = "/test/journals/2024_01_01.md"
        let timeString = "12:00"

        // Try path traversal attack with ../../.ssh/authorized_keys
        try await context.messageHandler.handleDocumentMessage(
            fileId: "malicious_123",
            fileName: "../../.ssh/authorized_keys",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify the file was saved with sanitized name (just "authorized_keys")
        let expectedAssetPath = "/test/kb/assets/authorized_keys"
        #expect(context.mockFileWorker.fileSystem[expectedAssetPath] != nil)

        // Verify malicious path was NOT used
        let maliciousPath = "/test/kb/../../.ssh/authorized_keys"
        #expect(context.mockFileWorker.fileSystem[maliciousPath] == nil)
    }

    @Test func handleDocumentMessageRejectsDotFileName() async throws {
        let context = MessageHandlerTestContext()
        context.mockBot.loadFileResult = (data: Data("test document".utf8), filePath: "file_path_info.pdf")

        let testPath = "/test/journals/2024_01_01.md"
        let timeString = "12:00"

        // Try using "." as filename
        try await context.messageHandler.handleDocumentMessage(
            fileId: "test_456",
            fileName: ".",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify the file was saved with fileId fallback instead of "."
        let expectedAssetPath = "/test/kb/assets/test_456.pdf"
        #expect(context.mockFileWorker.fileSystem[expectedAssetPath] != nil)
    }

    @Test func handleDocumentMessageRejectsDotDotFileName() async throws {
        let context = MessageHandlerTestContext()
        context.mockBot.loadFileResult = (data: Data("test document".utf8), filePath: "file_path_info.txt")

        let testPath = "/test/journals/2024_01_01.md"
        let timeString = "12:00"

        // Try using ".." as filename
        try await context.messageHandler.handleDocumentMessage(
            fileId: "test_789",
            fileName: "..",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify the file was saved with fileId fallback instead of ".."
        let expectedAssetPath = "/test/kb/assets/test_789.txt"
        #expect(context.mockFileWorker.fileSystem[expectedAssetPath] != nil)
    }

    @Test func handleDocumentMessageExtractsBaseNameFromComplexPath() async throws {
        let context = MessageHandlerTestContext()
        context.mockBot.loadFileResult = (data: Data("test document".utf8), filePath: "file_path_info.pdf")

        let testPath = "/test/journals/2024_01_01.md"
        let timeString = "12:00"

        // Try path with multiple directory components
        try await context.messageHandler.handleDocumentMessage(
            fileId: "test_complex",
            fileName: "/var/tmp/malicious/document.pdf",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
        )

        // Verify only the basename was used
        let expectedAssetPath = "/test/kb/assets/document.pdf"
        #expect(context.mockFileWorker.fileSystem[expectedAssetPath] != nil)

        // Verify full path was NOT used
        let maliciousPath = "/test/kb/assets/var/tmp/malicious/document.pdf"
        #expect(context.mockFileWorker.fileSystem[maliciousPath] == nil)
    }

    @Test func handleJustTextMessageWithOriginalSenderUsername() async throws {
        let context = MessageHandlerTestContext()
        let originalSender = Message.From(id: 456, name: "johndoe", firstName: "John", lastName: "Doe")

        let testPath = "/test/journal.md"
        let timeString = "14:30"
        let text = "Replied message"

        try await context.messageHandler.handleJustTextMessage(
            text: text,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **14:30** Replied message [[johndoe]] #stylus-inbox\n")
    }

    @Test func handleJustTextMessageWithOriginalSenderFullName() async throws {
        let context = MessageHandlerTestContext()
        let originalSender = Message.From(id: 456, name: nil, firstName: "Jane", lastName: "Smith")

        let testPath = "/test/journal.md"
        let timeString = "15:00"
        let text = "Forwarded message"

        try await context.messageHandler.handleJustTextMessage(
            text: text,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **15:00** Forwarded message [[Jane Smith]] #stylus-inbox\n")
    }

    @Test func handleJustTextMessageWithOriginalSenderFirstNameOnly() async throws {
        let context = MessageHandlerTestContext()
        let originalSender = Message.From(id: 789, name: nil, firstName: "Alice", lastName: nil)

        let testPath = "/test/journal.md"
        let timeString = "16:00"
        let text = "Reply from Alice"

        try await context.messageHandler.handleJustTextMessage(
            text: text,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == "- TODO **16:00** Reply from Alice [[Alice]] #stylus-inbox\n")
    }

    @Test func handleJustTextMessageWithOriginalSenderNoName() async throws {
        let context = MessageHandlerTestContext()
        let originalSender = Message.From(id: 999, name: nil, firstName: nil, lastName: nil)

        let testPath = "/test/journal.md"
        let timeString = "17:00"
        let text = "Anonymous sender"

        try await context.messageHandler.handleJustTextMessage(
            text: text,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        // Should not have user tag when no name is available
        #expect(writtenContent == "- TODO **17:00** Anonymous sender #stylus-inbox\n")
    }

    @Test func handleImageMessageWithOriginalSenderAndCaption() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8, 0xFF])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "photo.jpg")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "14:30"
        let caption = "Check this out"
        let originalSender = Message.From(id: 456, name: "jane_doe", firstName: "Jane", lastName: "Doe")

        try await context.messageHandler.handleImageMessage(
            fileId: "photo",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(writtenContent == """
        - TODO **14:30** Check this out [[jane_doe]] #stylus-inbox
        collapsed:: true
            - ![image](../assets/photo.jpg)

        """)
    }

    @Test func handleImageMessageWithOriginalSenderNoCaption() async throws {
        let context = MessageHandlerTestContext()
        let testImageData = Data([0xFF, 0xD8, 0xFF])
        context.mockBot.loadFileResult = (data: testImageData, filePath: "photo.jpg")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "15:00"
        let originalSender = Message.From(id: 456, name: nil, firstName: "Bob", lastName: "Jones")

        try await context.messageHandler.handleImageMessage(
            fileId: "photo",
            caption: nil,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **15:00** [[Bob Jones]] #stylus-inbox\ncollapsed:: true\n    - ![image](../assets/photo.jpg)\n",
        )
    }

    @Test func handleDocumentMessageWithOriginalSenderAndCaption() async throws {
        let context = MessageHandlerTestContext()
        let testDocumentData = Data([0x25, 0x50, 0x44, 0x46])
        context.mockBot.loadFileResult = (data: testDocumentData, filePath: "report.pdf")

        let testPath = "/test/kb/journals/2025_01_01.md"
        let timeString = "16:30"
        let caption = "Important report"
        let originalSender = Message.From(id: 789, name: "charlie", firstName: "Charlie", lastName: nil)

        try await context.messageHandler.handleDocumentMessage(
            fileId: "report",
            fileName: "report.pdf",
            caption: caption,
            timeString: timeString,
            filePath: testPath,
            originalSender: originalSender,
        )

        let writtenContent = try #require(context.mockFileWorker.fileSystem[testPath])
        #expect(
            writtenContent ==
                "- TODO **16:30** Important report [[charlie]] #stylus-inbox\ncollapsed:: true\n    - ![report.pdf](../assets/report.pdf)\n",
        )
    }
}
