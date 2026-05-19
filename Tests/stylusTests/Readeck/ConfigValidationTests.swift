import Foundation
@testable import stylus
import Testing

@Suite("Readeck Config Validation Tests")
struct ReadeckConfigValidationTests {
    @Test
    func `Config with readeck fields has non-nil values`() {
        let config = Config(
            telegramBotApiKey: SecretString("test-bot-token"),
            telegramUserID: 12345,
            knowledgeBaseLocation: "/tmp/kb",
            readeckEndpoint: "https://readeck.example.com",
            readeckApiToken: SecretString("test-api-token"),
        )

        #expect(config.readeckEndpoint == "https://readeck.example.com")
        #expect(config.readeckApiToken != nil)
        #expect(config.readeckApiToken?.unsafeValue == "test-api-token")
    }

    @Test
    func `Config without readeck fields has nil values`() {
        let config = Config(
            telegramBotApiKey: SecretString("test-bot-token"),
            telegramUserID: 12345,
            knowledgeBaseLocation: "/tmp/kb",
            readeckEndpoint: nil,
            readeckApiToken: nil,
        )

        #expect(config.readeckEndpoint == nil)
        #expect(config.readeckApiToken == nil)
    }

    @Test
    func `Config description redacts API token`() {
        let config = Config(
            telegramBotApiKey: SecretString("secret-bot-token"),
            telegramUserID: 12345,
            knowledgeBaseLocation: "/tmp/kb",
            readeckEndpoint: "https://readeck.example.com",
            readeckApiToken: SecretString("secret-api-token"),
        )

        let description = config.description
        #expect(!description.contains("secret-api-token"))
        #expect(!description.contains("secret-bot-token"))
        #expect(description.contains("[REDACTED]"))
    }

    @Test
    func `SecretString redacts in description`() {
        let secret = SecretString("my-secret-value")
        #expect(secret.description == "[REDACTED]")
        #expect(secret.debugDescription == "[REDACTED]")
        #expect(secret.unsafeValue == "my-secret-value")
    }

    @Test
    func `SecretString isEmpty works correctly`() {
        #expect(SecretString("").isEmpty)
        #expect(!SecretString("value").isEmpty)
    }
}
