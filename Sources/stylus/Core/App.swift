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

            let timeString = await dateFormatter.formatDate("HH:mm", date: message.date)
            switch message.messageType {
            case let .justText(text):
                do {
                    let processedText = await linkProcessor.processLinks(in: text)
                    let taggedText = addStylusInboxTag(to: processedText)
                    let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"
                    try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
                } catch {
                    print("Error processing message: \(text), err: \(error)")
                    continue
                }

            case let .image(fileId, caption):
                do {
                    // 1. Ensure assets directory exists
                    let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("assets")
                    try await journalWriter.ensureDirectoryExists(at: assetsURL.path)

                    // 2. Load the best quality image and save to assets folder
                    let fileData = try await bot.loadFile(with: fileId)
                    let fileName = "\(fileId).jpg" // Telegram images are usually JPEGs
                    let assetFilePath = assetsURL.appendingPathComponent(fileName).path

                    // Save image to assets folder
                    try await journalWriter.saveImageFile(data: fileData, to: assetFilePath)

                    // 3. Create markdown image reference
                    let imageMarkdown = "![Image](../assets/\(fileName))"

                    // 4. Combine caption with image reference
                    let captionText = caption ?? ""
                    let fullText = captionText.isEmpty ? imageMarkdown : "\(captionText)\n\n\(imageMarkdown)"

                    let taggedText = addStylusInboxTag(to: fullText)
                    let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"
                    try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
                } catch {
                    print("Error processing image err: \(error)")
                    continue
                }
            }

            print("Successfully added to journal: \(filePath)")
            bot.respondAsSaved(on: message)
        }
        // If we reach here, the bot.launch() stream has terminated.
        // This could be a graceful shutdown or an unexpected termination.
        // If you expect the bot to run indefinitely, treat this as an error.
        fatalError("Bot stream terminated unexpectedly. The bot should run continuously unless explicitly stopped.")
    }
}
