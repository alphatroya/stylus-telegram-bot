import Foundation
import TelegramBotSDK

// MARK: - stylus

@main
struct stylus {
    static func main() async throws {
        let config = try await readConfig(provider: yamlProvider())

        let bot = TelegramBot(token: config.telegramBotApiKey)

        while let update = bot.nextUpdateSync() {
            if let message = update.message,
               let from = message.from,
               from.id == config.telegramUserID,
               let text = message.text
            {
                let today = formatDate("yyyy_MM_dd", date: message.date)
                let fileName = "\(today).md"
                let journalsPath = (config.knowledgeBaseLocation as NSString).appendingPathComponent("journals")
                let filePath = (journalsPath as NSString).appendingPathComponent(fileName)

                do {
                    try ensureDirectoryExists(at: journalsPath)

                    let timeString = formatDate("HH:mm")
                    let lineToAppend = "- TODO **\(timeString)** \(text)\n"

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
