import ArgumentParser
import Foundation

// MARK: - Stylus

@main
struct Stylus: AsyncParsableCommand {
    // MARK: Static Properties

    static let configuration = CommandConfiguration(
        commandName: "stylus",
        abstract: "Telegram bot for link processing and Readeck sync",
    )

    // MARK: Properties

    @Flag(name: .shortAndLong, help: "Run Readeck sync mode")
    var readeck: Bool = false

    // MARK: Functions

    func run() async throws {
        let config = try await readConfig(provider: yamlProvider())

        if readeck {
            validateReadeckConfig(config)
            let runner = ReadeckSyncRunner(config: config)
            try await runner.run()
        } else {
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

    // MARK: Private Functions

    private func validateReadeckConfig(_ config: Config) {
        guard config.readeckEndpoint != nil else {
            print("Error: --readeck flag requires 'readeckEndpoint' in config file")
            Foundation.exit(1)
        }
        guard config.readeckApiToken != nil else {
            print("Error: --readeck flag requires 'readeckApiToken' in config file")
            Foundation.exit(1)
        }
    }
}
