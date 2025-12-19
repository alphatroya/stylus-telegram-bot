import Foundation

struct App {
    // MARK: Properties

    var config: Config
    var journalWriter: JournalWriter = .init()
    var linkProcessor: LinkProcessor = .init()
    var dateFormatter: StylusDateFormatter = .init()
    var bot: Bot

    // MARK: Functions

    /// Internal for reuse and testing from the test target.
    internal func handleJustTextMessage(text: String, timeString: String, filePath: String) async throws {
        let processedText = await linkProcessor.processLinks(in: text)
        let taggedText = addStylusInboxTag(to: processedText)
        let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"
        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

    /// Internal for reuse and testing from the test target.
    internal func handleImageMessage(fileId: String, caption: String?, timeString: String, filePath: String) async throws {
        let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("assets")
        try await journalWriter.ensureDirectoryExists(at: assetsURL.path)

        let (fileData, filePathInfo) = try await bot.loadFile(with: fileId)
        let fileExtension = URL(fileURLWithPath: filePathInfo).pathExtension
        let fileName = fileExtension.isEmpty ? "\(fileId)" : "\(fileId).\(fileExtension)"
        let assetFilePath = assetsURL.appendingPathComponent(fileName).path

        try await journalWriter.saveImageFile(data: fileData, to: assetFilePath)

        let imageMarkdown = "![image](../assets/\(fileName))"

        let captionText = caption ?? ""
        let processedCaption = addStylusInboxTag(to: captionText)
        let lineToAppend = if captionText.isEmpty {
            "- TODO **\(timeString)** #stylus-inbox\ncollapsed:: true\n    - \(imageMarkdown)\n"
        } else {
            "- TODO **\(timeString)** \(processedCaption)\ncollapsed:: true\n    - \(imageMarkdown)\n"
        }

        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

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
                    try await handleJustTextMessage(text: text, timeString: timeString, filePath: filePath)
                } catch {
                    print("Error processing message: \(text), err: \(error)")
                    continue
                }

            case let .image(fileId, caption):
                do {
                    try await handleImageMessage(fileId: fileId, caption: caption, timeString: timeString, filePath: filePath)
                } catch {
                    print("Error processing image err: \(error)")
                    continue
                }
            }

            print("Successfully added to journal: \(filePath)")
            bot.respondAsSaved(on: message)
        }
        fatalError("Bot stream terminated unexpectedly. The bot should run continuously unless explicitly stopped.")
    }
}
