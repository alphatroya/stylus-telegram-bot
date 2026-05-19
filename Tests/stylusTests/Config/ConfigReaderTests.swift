import Configuration
import Foundation
@testable import stylus
import Testing

// MARK: - SecretString + Equatable

extension SecretString: Equatable {
    public static func == (lhs: SecretString, rhs: SecretString) -> Bool {
        lhs.unsafeValue == rhs.unsafeValue
    }
}

// MARK: - SecretString + Hashable

extension SecretString: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(unsafeValue)
    }
}

private func inMemoryStorage(values: [String: ConfigValue] = [:]) -> InMemoryProvider {
    InMemoryProvider(name: "provider", values: values)
}

// MARK: - ConfigReaderTests

@Suite("ConfigReaderTests")
struct ConfigReaderTests {
    @Test func `success with all required keys`() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        let config = try readConfig(provider: provider)

        #expect(config.telegramBotApiKey == SecretString("test-api-key"))
        #expect(config.telegramBotApiKey.unsafeValue == "test-api-key")
        #expect(config.telegramUserID == 123_456_789)
        #expect(config.knowledgeBaseLocation == "/path/to/knowledge")
    }

    @Test func `throws when telegram bot api key missing`() {
        let provider = inMemoryStorage(values: [
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func `throws when telegram user ID missing`() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "knowledgeBaseLocation": "/path/to/knowledge",
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func `throws when knowledge base location missing`() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "telegramUserId": 123_456_789,
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func `throws when all keys missing`() {
        let provider = inMemoryStorage(values: [:])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func `secret string hides value in description`() {
        let secret = SecretString("super-secret-api-key")

        #expect(String(describing: secret) == "[REDACTED]")
        #expect(String(reflecting: secret) == "[REDACTED]")
        #expect(secret.unsafeValue == "super-secret-api-key")
    }

    @Test func `config hides api key in description`() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "secret-token-12345",
            "telegramUserId": 987_654_321,
            "knowledgeBaseLocation": "/home/user/knowledge",
        ])

        let config = try readConfig(provider: provider)
        let description = String(describing: config)
        let debugDescription = String(reflecting: config)

        // API key should be redacted in descriptions
        #expect(!description.contains("secret-token-12345"))
        #expect(!debugDescription.contains("secret-token-12345"))
        #expect(description.contains("[REDACTED]"))
        #expect(description.contains("987654321"))
        #expect(description.contains("/home/user/knowledge"))
    }
}
