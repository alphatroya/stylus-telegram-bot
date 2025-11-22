import Foundation
import TelegramBotSDK

// MARK: - Bot

struct Bot {
    // MARK: Properties

    let config: Config
    let journalWriter: JournalWriter
    let linkProcessor: LinkProcessor

    // MARK: Lifecycle

    init(config: Config, journalWriter: JournalWriter = .init(), linkProcessor: LinkProcessor = .init()) {
        self.config = config
        self.journalWriter = journalWriter
        self.linkProcessor = linkProcessor
    }

    // MARK: Functions

    func run() async throws {
        let bot = TelegramBot(token: config.telegramBotApiKey)
        let journalsPath = (config.knowledgeBaseLocation as NSString).appendingPathComponent("journals")
        try journalWriter.ensureDirectoryExists(at: journalsPath)

        while let update = bot.nextUpdateSync() {
            guard let message = update.message,
                  let from = message.from,
                  let text = message.text
            else {
                continue
            }
            guard from.id == config.telegramUserID else {
                print("Wrong user sent a message, \(from.id) - \(from.username ?? "NONE")")
                continue
            }

            let messageDateFormatted = await formatDate("yyyy_MM_dd", date: message.date)
            let filePath = (journalsPath as NSString).appendingPathComponent("\(messageDateFormatted).md")

            do {
                let timeString = await formatDate("HH:mm", date: message.date)
                // Process links first
                let processedText = await linkProcessor.processLinks(
                    in: text,
                )
                let taggedText = addStylusInboxTag(to: processedText)
                let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"

                try journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)

                print("Successfully added to journal: \(filePath)")
                bot.sendMessageAsync(
                    chatId: .chat(from.id),
                    text: "✅ Entry saved to your journal",
                    replyToMessageId: message.messageId,
                )
            } catch {
                print("Error: \(error)")
            }
        }

        fatalError("Server stopped due to error: \(bot.lastError, default: "NONE")")
    }
}
