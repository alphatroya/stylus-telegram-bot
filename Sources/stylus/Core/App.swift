import Foundation

struct App {
    // MARK: Properties

    var config: Config
    var journalWriter: JournalWriter = .init()
    var linkProcessor: LinkProcessor = .init()
    var dateFormatter: StylusDateFormatter = .init()
    var bot: Bot

    // MARK: Functions

    func run() async throws {
        let journalsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("journals")
        try await journalWriter.ensureDirectoryExists(at: journalsURL.path)
        let sequence = bot.launch()

        for try await message in sequence {
            guard message.from.id == config.telegramUserID else {
                print(
                    "Wrong user sent a message, \(message.from.id) - \(message.from.name ?? "NONE")",
                )
                continue
            }

            let messageDateFormatted = await dateFormatter.formatDate("yyyy_MM_dd", date: message.date)
            let filePath = journalsURL.appendingPathComponent("\(messageDateFormatted).md").path

            switch message.messageType {
            case let .justText(text):
                do {
                    let timeString = await dateFormatter.formatDate("HH:mm", date: message.date)
                    let processedText = await linkProcessor.processLinks(in: text)
                    let taggedText = addStylusInboxTag(to: processedText)
                    let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"

                    try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)

                    print("Successfully added to journal: \(filePath)")
                    bot.respondAsSaved(on: message)
                } catch {
                    print("Error: \(error)")
                }
            }
        }
        // If we reach here, the bot.launch() stream has terminated.
        // This could be a graceful shutdown or an unexpected termination.
        // If you expect the bot to run indefinitely, treat this as an error.
        fatalError("Bot stream terminated unexpectedly. The bot should run continuously unless explicitly stopped.")
    }
}
