import Foundation

// MARK: - Stylus

@main
struct Stylus {
    static func main() async throws {
        let config = try await readConfig(provider: yamlProvider())
        let telegramBot = TelegramBot(
            config: .init(token: config.telegramBotApiKey.unsafeValue),
        )
        let journalWriter = JournalWriter()
        let linkProcessor = LinkProcessor()

        let messageHandler = DefaultMessageHandler(
            config: config,
            journalWriter: journalWriter,
            linkProcessor: linkProcessor,
            bot: telegramBot,
        )

        let bot = App(
            config: config,
            bot: telegramBot,
            messageHandler: messageHandler,
        )
        try await bot.run()
    }
}
