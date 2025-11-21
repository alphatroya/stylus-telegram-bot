import Configuration
import Foundation
@testable import stylus
import Testing

private func inMemoryStorage(values: [String: ConfigValue] = [:]) -> InMemoryProvider {
    InMemoryProvider(name: "provider", values: values)
}

// MARK: - ConfigReaderTests

@Suite("ConfigReaderTests")
struct ConfigReaderTests {
    @Test func successWithAllRequiredKeys() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        let config = try readConfig(provider: provider)

        #expect(config.telegramBotApiKey == "test-api-key")
        #expect(config.telegramUserID == 123_456_789)
        #expect(config.knowledgeBaseLocation == "/path/to/knowledge")
    }

    @Test func throwsWhenTelegramBotApiKeyMissing() {
        let provider = inMemoryStorage(values: [
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenTelegramUserIDMissing() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenKnowledgeBaseLocationMissing() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "telegramUserId": 123_456_789,
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenAllKeysMissing() {
        let provider = inMemoryStorage(values: [:])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }
}
