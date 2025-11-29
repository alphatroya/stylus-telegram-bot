import Configuration
import Foundation
import SystemPackage

// MARK: - SecretString

/// A wrapper for sensitive string values that prevents accidental exposure in logs, debug output, and string interpolation.
struct SecretString {
    // MARK: Properties

    private let value: String

    // MARK: Computed Properties

    /// Safely access the underlying secret value
    var unsafeValue: String {
        value
    }

    /// Check if the secret is empty
    var isEmpty: Bool {
        value.isEmpty
    }

    // MARK: Lifecycle

    init(_ value: String) {
        self.value = value
    }
}

// MARK: CustomStringConvertible

extension SecretString: CustomStringConvertible {
    var description: String {
        "[REDACTED]"
    }
}

// MARK: CustomDebugStringConvertible

extension SecretString: CustomDebugStringConvertible {
    var debugDescription: String {
        "[REDACTED]"
    }
}

// MARK: Equatable

extension SecretString: Equatable {
    static func == (lhs: SecretString, rhs: SecretString) -> Bool {
        lhs.value == rhs.value
    }
}

// MARK: Hashable

extension SecretString: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

// MARK: Codable

extension SecretString: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Config

/// Configuration structure for the Stylus Telegram Bot.
///
/// Security Notes:
/// - The `telegramBotApiKey` is wrapped in `SecretString` to prevent accidental exposure in logs, debug output, or string interpolation
/// - Always use `.unsafeValue` when you need to access the actual API key value for API calls
/// - The `Config` struct implements custom `description` and `debugDescription` to redact sensitive information
struct Config {
    /// Telegram Bot API token (wrapped in SecretString for security)
    let telegramBotApiKey: SecretString
    /// Telegram user ID authorized to use the bot
    let telegramUserID: Int
    /// Path to the knowledge base directory
    let knowledgeBaseLocation: String
}

// MARK: CustomStringConvertible

extension Config: CustomStringConvertible {
    var description: String {
        "Config(telegramBotApiKey: [REDACTED], telegramUserID: \(telegramUserID), knowledgeBaseLocation: \"\(knowledgeBaseLocation)\")"
    }
}

// MARK: CustomDebugStringConvertible

extension Config: CustomDebugStringConvertible {
    var debugDescription: String {
        description
    }
}

func yamlProvider() async throws -> YAMLProvider {
    let configPath = ConfigPath.path
    let filePath = FilePath(configPath)
    return try await YAMLProvider(filePath: filePath)
}

/// Reads and validates configuration from the provided ConfigProvider.
///
/// The API key is automatically wrapped in `SecretString` for security, ensuring it won't be
/// accidentally exposed in logs or debug output.
///
/// - Parameter provider: The configuration provider (typically YAML file)
/// - Returns: A validated `Config` instance
/// - Throws: Configuration errors if required keys are missing or invalid
func readConfig(provider: ConfigProvider) throws -> Config {
    let configReader = ConfigReader(providers: [provider])

    return try .init(
        telegramBotApiKey: SecretString(configReader.requiredString(forKey: "telegramBotApiKey", isSecret: true)),
        telegramUserID: configReader.requiredInt(forKey: "telegramUserId"),
        knowledgeBaseLocation: configReader.requiredString(forKey: "knowledgeBaseLocation"),
    )
}
