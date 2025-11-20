import Configuration
import SystemPackage

// MARK: - Config

struct Config {
    let telegramBotApiKey: String
    let telegramUserID: Int
    let knowledgeBaseLocation: String
}

func yamlProvider() async throws -> YAMLProvider {
    let configPath = ConfigPath.path
    let filePath = FilePath(configPath)
    return try await YAMLProvider(filePath: filePath)
}

func readConfig(provider: ConfigProvider) throws -> Config {
    let configReader = ConfigReader(providers: [provider])

    return try .init(
        telegramBotApiKey: configReader.requiredString(forKey: "telegramBotApiKey", isSecret: true),
        telegramUserID: configReader.requiredInt(forKey: "telegramUserId"),
        knowledgeBaseLocation: configReader.requiredString(forKey: "knowledgeBaseLocation"),
    )
}
