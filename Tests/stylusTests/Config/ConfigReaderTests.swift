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
    @Test func successWithAllRequiredKeys() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/tmp",
        ])

        let config = try readConfig(provider: provider)

        #expect(config.telegramBotApiKey == SecretString("test-api-key"))
        #expect(config.telegramBotApiKey.unsafeValue == "test-api-key")
        #expect(config.telegramUserID == 123_456_789)
        #expect(config.knowledgeBaseLocation == "/tmp")
    }

    @Test func throwsWhenTelegramBotApiKeyMissing() {
        let provider = inMemoryStorage(values: [
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/tmp",
        ])

        #expect(throws: (any Error).self) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenTelegramUserIDMissing() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "test-api-key",
            "knowledgeBaseLocation": "/tmp",
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

    @Test func secretStringHidesValueInDescription() {
        let secret = SecretString("super-secret-api-key")

        #expect(String(describing: secret) == "[REDACTED]")
        #expect(String(reflecting: secret) == "[REDACTED]")
        #expect(secret.unsafeValue == "super-secret-api-key")
    }

    @Test func configHidesApiKeyInDescription() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "secret-token-12345",
            "telegramUserId": 987_654_321,
            "knowledgeBaseLocation": "/tmp",
        ])

        let config = try readConfig(provider: provider)
        let description = String(describing: config)
        let debugDescription = String(reflecting: config)

        // API key should be redacted in descriptions
        #expect(!description.contains("secret-token-12345"))
        #expect(!debugDescription.contains("secret-token-12345"))
        #expect(description.contains("[REDACTED]"))
        #expect(description.contains("987654321"))
        #expect(description.contains("/tmp"))
    }

    // MARK: - Validation Tests

    @Test func throwsWhenApiKeyIsEmpty() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/tmp",
        ])

        #expect(throws: ConfigValidationError.emptyApiKey) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenApiKeyIsWhitespace() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "   \n\t   ",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/tmp",
        ])

        #expect(throws: ConfigValidationError.emptyApiKey) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenUserIdIsZero() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 0,
            "knowledgeBaseLocation": "/tmp",
        ])

        #expect(throws: ConfigValidationError.invalidUserId(0)) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenUserIdIsNegative() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": -123,
            "knowledgeBaseLocation": "/tmp",
        ])

        #expect(throws: ConfigValidationError.invalidUserId(-123)) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenKnowledgeBasePathIsEmpty() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "",
        ])

        #expect(throws: ConfigValidationError.invalidKnowledgeBasePath("", reason: "path cannot be empty")) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenKnowledgeBasePathIsSystemDirectory() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/System/Applications",
        ])

        #expect(throws: ConfigValidationError.systemPathNotAllowed("/System/Applications")) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenKnowledgeBasePathIsUsrDirectory() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/usr/local",
        ])

        #expect(throws: ConfigValidationError.systemPathNotAllowed("/usr/local")) {
            try readConfig(provider: provider)
        }
    }

    @Test func throwsWhenKnowledgeBaseParentDoesNotExist() {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/non/existent/parent/dir",
        ])

        let expectedReason = "parent directory '/non/existent/parent' does not exist"
        #expect(throws: ConfigValidationError.invalidKnowledgeBasePath("/non/existent/parent/dir", reason: expectedReason)) {
            try readConfig(provider: provider)
        }
    }

    @Test func allowsTrimmedApiKey() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "  valid-api-key  ",
            "telegramUserId": 123_456_789,
            "knowledgeBaseLocation": "/tmp",
        ])

        let config = try readConfig(provider: provider)
        #expect(config.telegramBotApiKey.unsafeValue == "  valid-api-key  ")
    }

    @Test func allowsPositiveUserId() throws {
        let provider = inMemoryStorage(values: [
            "telegramBotApiKey": "valid-api-key",
            "telegramUserId": 999_999_999,
            "knowledgeBaseLocation": "/tmp",
        ])

        let config = try readConfig(provider: provider)
        #expect(config.telegramUserID == 999_999_999)
    }

    @Test func configValidationErrorHasCorrectErrorMessages() {
        let emptyApiKeyError = ConfigValidationError.emptyApiKey
        #expect(emptyApiKeyError.localizedDescription == "Telegram Bot API key cannot be empty")

        let invalidUserIdError = ConfigValidationError.invalidUserId(-5)
        #expect(invalidUserIdError
            .localizedDescription == "Invalid Telegram user ID: -5. User ID must be a positive integer greater than 0")

        let systemPathError = ConfigValidationError.systemPathNotAllowed("/System/test")
        #expect(systemPathError
            .localizedDescription ==
            "Knowledge base location '/System/test' points to a system directory. Please choose a different location")

        let pathNotWritableError = ConfigValidationError.pathNotWritable("/read/only/path")
        #expect(pathNotWritableError
            .localizedDescription == "Knowledge base location '/read/only/path' is not writable. Please check permissions")
    }

    @Test func configValidationErrorHasRecoverySuggestions() {
        let emptyApiKeyError = ConfigValidationError.emptyApiKey
        #expect(emptyApiKeyError.recoverySuggestion == "Get a valid API token from @BotFather on Telegram and update your config.yaml file")

        let invalidUserIdError = ConfigValidationError.invalidUserId(0)
        #expect(invalidUserIdError.recoverySuggestion == "Get your user ID from @userinfobot on Telegram and update your config.yaml file")

        let systemPathError = ConfigValidationError.systemPathNotAllowed("/usr/local")
        #expect(systemPathError.recoverySuggestion == "Choose a location in your home directory, such as ~/Documents/knowledge-base")
    }
}
