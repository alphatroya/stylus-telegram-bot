import Foundation
@testable import stylus
import Testing

// MARK: - TestContext

struct TestContext {
    // MARK: Properties

    let mockFileWorker: MockFileWorker
    let journalWriter: JournalWriter
    let config: Config
    let mockBot: MockBot
    let mockMessageHandler: MockMessageHandler
    let app: App

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
        mockMessageHandler = MockMessageHandler()
        app = App(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: LinkProcessor(),
            dateFormatter: StylusDateFormatter(),
            bot: mockBot,
            messageHandler: mockMessageHandler,
        )
    }
}

// MARK: - AppTests

@Suite("AppTests")
struct AppTests {
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
}
