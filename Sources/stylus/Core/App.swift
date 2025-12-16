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

                    // 2. Download the file and get its path with extension
                    let (fileData, filePathInfo) = try await bot.loadFile(with: fileId)
                    let fileExtension = URL(fileURLWithPath: filePathInfo).pathExtension
                    let fileName = fileExtension.isEmpty ? "\(fileId)" : "\(fileId).\(fileExtension)"
                    let assetFilePath = assetsURL.appendingPathComponent(fileName).path

                    // 3. Save image to assets folder
                    try await journalWriter.saveImageFile(data: fileData, to: assetFilePath)

                    // 4. Create markdown image reference
                    let imageMarkdown = "![image](../assets/\(fileName))"

                    // 5. Build the entry with caption and collapsed section
                    let captionText = caption ?? ""
                    let lineToAppend = if captionText.isEmpty {
                        "- **\(timeString)** #stylus-inbox\ncollapsed:: true\n    - \(imageMarkdown)\n"
                    } else {
                        "- **\(timeString)** \(captionText) #stylus-inbox\ncollapsed:: true\n    - \(imageMarkdown)\n"
                    }

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
