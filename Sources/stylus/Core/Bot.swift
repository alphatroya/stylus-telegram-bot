import Foundation
import TelegramBotSDK

// MARK: - Bot

struct Bot {
    // MARK: Properties

    var config: Config
    var journalWriter: JournalWriter = .init()
    var linkProcessor: LinkProcessor = .init()
    var dateFormatter: StylusDateFormatter = .init()

    // MARK: Functions

    func run() async throws {
        let bot = TelegramBot(token: config.telegramBotApiKey)
        let journalsPath = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("journals").path
        try journalWriter.ensureDirectoryExists(at: journalsPath)

        while let update = bot.nextUpdateSync() {
            guard let message = update.message, let from = message.from else {
                print("Skipping update - missing message or sender information")
                continue
            }
            guard let text = message.text else {
                print("Skipping update - message has no text content")
                continue
            }
            guard from.id == config.telegramUserID else {
                print("Wrong user sent a message, \(from.id) - \(from.username ?? "NONE")")
                continue
            }

            let messageDateFormatted = await dateFormatter.formatDate("yyyy_MM_dd", date: message.date)
            let filePath = URL(fileURLWithPath: journalsPath).appendingPathComponent("\(messageDateFormatted).md").path

            do {
                let timeString = await dateFormatter.formatDate("HH:mm", date: message.date)
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
