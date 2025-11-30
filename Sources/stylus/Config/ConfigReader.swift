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

// MARK: - ConfigValidationError

/// Errors that can occur during configuration validation
enum ConfigValidationError: Error {
    case emptyApiKey
    case invalidUserId(Int)
    case invalidKnowledgeBasePath(String, reason: String)
    case pathNotWritable(String)
    case systemPathNotAllowed(String)
    case pathIsFile(String)
}

// MARK: Equatable

extension ConfigValidationError: Equatable {
    static func == (lhs: ConfigValidationError, rhs: ConfigValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyApiKey, .emptyApiKey):
            true
        case let (.invalidUserId(lhsId), .invalidUserId(rhsId)):
            lhsId == rhsId
        case let (.invalidKnowledgeBasePath(lhsPath, lhsReason), .invalidKnowledgeBasePath(rhsPath, rhsReason)):
            lhsPath == rhsPath && lhsReason == rhsReason
        case let (.pathNotWritable(lhsPath), .pathNotWritable(rhsPath)):
            lhsPath == rhsPath
        case let (.systemPathNotAllowed(lhsPath), .systemPathNotAllowed(rhsPath)):
            lhsPath == rhsPath
        case let (.pathIsFile(lhsPath), .pathIsFile(rhsPath)):
            lhsPath == rhsPath
        default:
            false
        }
    }
}

// MARK: LocalizedError

extension ConfigValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyApiKey:
            "Telegram Bot API key cannot be empty"
        case let .invalidUserId(id):
            "Invalid Telegram user ID: \(id). User ID must be a positive integer greater than 0"
        case let .invalidKnowledgeBasePath(path, reason):
            "Invalid knowledge base location '\(path)': \(reason)"
        case let .pathNotWritable(path):
            "Knowledge base location '\(path)' is not writable. Please check permissions"
        case let .systemPathNotAllowed(path):
            "Knowledge base location '\(path)' points to a system directory. Please choose a different location"
        case let .pathIsFile(path):
            "Knowledge base location '\(path)' is a file, not a directory. Please specify a directory path"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyApiKey:
            "Get a valid API token from @BotFather on Telegram and update your config.yaml file"
        case .invalidUserId:
            "Get your user ID from @userinfobot on Telegram and update your config.yaml file"
        case .invalidKnowledgeBasePath, .pathNotWritable:
            "Create the directory or choose a location where you have write permissions"
        case .systemPathNotAllowed:
            "Choose a location in your home directory, such as ~/Documents/knowledge-base"
        case .pathIsFile:
            "Remove the file or choose a different path for your knowledge base directory"
        }
    }
}

// MARK: - Configuration Validation

/// Validates the Knowledge Base location path
/// - Parameter path: The knowledge base path to validate
/// - Throws: ConfigValidationError if the path is invalid
func validateKnowledgeBasePath(_ path: String) throws {
    let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check if path is empty
    guard !trimmedPath.isEmpty else {
        throw ConfigValidationError.invalidKnowledgeBasePath(path, reason: "path cannot be empty")
    }

    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: trimmedPath)
    let expandedPath = url.standardized.path

    // Check for system paths that should not be used
    let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/var", "/etc", "/Library/System"]
    for systemPath in systemPaths {
        if expandedPath.hasPrefix(systemPath) {
            throw ConfigValidationError.systemPathNotAllowed(expandedPath)
        }
    }

    // Check if path exists
    var isDirectory: ObjCBool = false
    let pathExists = fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

    if pathExists {
        // Path exists - check if it's a directory
        if !isDirectory.boolValue {
            throw ConfigValidationError.pathIsFile(expandedPath)
        }

        // Check if directory is writable
        if !fileManager.isWritableFile(atPath: expandedPath) {
            throw ConfigValidationError.pathNotWritable(expandedPath)
        }
    } else {
        // Path doesn't exist - check if parent directory exists and is writable
        let parentPath = url.deletingLastPathComponent().path
        var parentIsDirectory: ObjCBool = false
        let parentExists = fileManager.fileExists(atPath: parentPath, isDirectory: &parentIsDirectory)

        if !parentExists {
            throw ConfigValidationError.invalidKnowledgeBasePath(expandedPath, reason: "parent directory '\(parentPath)' does not exist")
        }

        if !parentIsDirectory.boolValue {
            throw ConfigValidationError.invalidKnowledgeBasePath(expandedPath, reason: "parent path '\(parentPath)' is not a directory")
        }

        if !fileManager.isWritableFile(atPath: parentPath) {
            throw ConfigValidationError.pathNotWritable(parentPath)
        }
    }
}

/// Validates the Telegram Bot API key
/// - Parameter apiKey: The API key to validate
/// - Throws: ConfigValidationError if the API key is invalid
func validateApiKey(_ apiKey: String) throws {
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedKey.isEmpty else {
        throw ConfigValidationError.emptyApiKey
    }
}

/// Validates the Telegram user ID
/// - Parameter userID: The user ID to validate
/// - Throws: ConfigValidationError if the user ID is invalid
func validateUserID(_ userID: Int) throws {
    guard userID > 0 else {
        throw ConfigValidationError.invalidUserId(userID)
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
/// Performs comprehensive validation of all configuration values including:
/// - API key: non-empty after trimming
/// - User ID: positive integer greater than 0
/// - Knowledge base location: valid path, writable, not a system directory
///
/// - Parameter provider: The configuration provider (typically YAML file)
/// - Returns: A validated `Config` instance
/// - Throws: ConfigValidationError for validation failures, or Configuration errors for missing keys
func readConfig(provider: ConfigProvider) throws -> Config {
    let configReader = ConfigReader(providers: [provider])

    // Read raw values from configuration
    let apiKey = try configReader.requiredString(forKey: "telegramBotApiKey", isSecret: true)
    let userID = try configReader.requiredInt(forKey: "telegramUserId")
    let knowledgeBasePath = try configReader.requiredString(forKey: "knowledgeBaseLocation")

    // Validate all configuration values
    try validateApiKey(apiKey)
    try validateUserID(userID)
    try validateKnowledgeBasePath(knowledgeBasePath)

    return .init(
        telegramBotApiKey: SecretString(apiKey),
        telegramUserID: userID,
        knowledgeBaseLocation: knowledgeBasePath,
    )
}
