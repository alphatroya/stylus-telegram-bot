import Foundation
import TelegramBotSDK

// MARK: - stylus

@main
struct stylus {
    static func main() async throws {
        let config = try await readConfig(provider: yamlProvider())

        let bot = TelegramBot(token: config.telegramBotApiKey)
        let journalsPath = (config.knowledgeBaseLocation as NSString).appendingPathComponent("journals")
        try ensureDirectoryExists(at: journalsPath)

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

            let messageDateFormatted = formatDate("yyyy_MM_dd", date: message.date)
            let filePath = (journalsPath as NSString).appendingPathComponent("\(messageDateFormatted).md")

            do {
                let timeString = formatDate("HH:mm", date: message.date)
                let taggedText = addStylusInboxTag(to: text)
                let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"

                try appendToJournalFile(at: filePath, content: lineToAppend)

                print("Successfully added to journal: \(filePath)")
                bot.sendMessageAsync(
                    chatId: .chat(from.id),
                    text: "Successfully added to journal!\n\(text)",
                )
            } catch {
                print("Error: \(error)")
            }
        }

        fatalError("Server stopped due to error: \(bot.lastError, default: "NONE")")
    }
}

func formatDate(_ format: String, date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

func ensureDirectoryExists(at path: String, fileManager: FileWorker = .system) throws {
    if !fileManager.fileExistsAtPath(path) {
        try fileManager.createDirectoryAtPath(path, true, nil)
    }
}

func appendToJournalFile(at filePath: String, content: String, fileManager: FileWorker = .system) throws {
    if fileManager.fileExistsAtPath(filePath) {
        let currentContent = try fileManager.contentsAtPath(filePath) ?? ""
        let needsNewline = !currentContent.isEmpty && !currentContent.hasSuffix("\n")
        let contentToAppend = needsNewline ? "\n" + content : content

        let fileHandle = try fileManager.fileHandleForWritingToPath(filePath)
        _ = fileHandle.seekToEndOfFile()
        fileHandle.write(contentToAppend.data(using: .utf8)!)
        fileHandle.closeFile()
    } else {
        try fileManager.writeStringToFile(content, filePath, true, .utf8)
    }
}
