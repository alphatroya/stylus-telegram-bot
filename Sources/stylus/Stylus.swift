import Foundation

// MARK: - Stylus

@main
struct Stylus {
    static func main() async throws {
        let config = try await readConfig(provider: yamlProvider())
        let bot = App(
            config: config,
            bot: TelegramBot(
                config: .init(token: config.telegramBotApiKey.unsafeValue),
            ),
        )
        try await bot.run()
    }
}
