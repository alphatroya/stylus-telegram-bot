import Foundation

// MARK: - FileNameGenerationError

enum FileNameGenerationError: Error, LocalizedError {
    case maxRetriesExceeded(fileName: String, attempts: Int)

    // MARK: Computed Properties

    var errorDescription: String? {
        switch self {
        case let .maxRetriesExceeded(fileName, attempts):
            "Failed to generate unique filename for '\(fileName)' after \(attempts) attempts"
        }
    }
}

// MARK: - App

struct App {
    // MARK: Static Properties

    // MARK: Constants

    private static let uuidSuffixLength = 8
    private static let maxFileNameRetries = 100

    // MARK: Properties

    var config: Config
    var journalWriter: JournalWriter = .init()
    var linkProcessor: LinkProcessor = .init()
    var dateFormatter: StylusDateFormatter = .init()
    var bot: Bot

    // MARK: Functions

    /// Internal for reuse and testing from the test target.
    func handleJustTextMessage(text: String, timeString: String, filePath: String) async throws {
        let processedText = await linkProcessor.processLinks(in: text)
        let taggedText = addStylusInboxTag(to: processedText)
        let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"
        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

    /// Internal for reuse and testing from the test target.
    func handleImageMessage(fileId: String, caption: String?, timeString: String, filePath: String) async throws {
        let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("assets")
        try await journalWriter.ensureDirectoryExists(at: assetsURL.path)

        let (fileData, filePathInfo) = try await bot.loadFile(with: fileId)
        let fileExtension = URL(fileURLWithPath: filePathInfo).pathExtension
        let baseFileName = fileExtension.isEmpty ? "\(fileId)" : "\(fileId).\(fileExtension)"
        let fileName = try await saveFileWithUniqueFilename(
            data: fileData,
            baseFileName: baseFileName,
            assetsURL: assetsURL,
        )

        let imageMarkdown = "![image](../assets/\(fileName))"

        let captionText = caption ?? ""
        let processedCaptionText = await linkProcessor.processLinks(in: captionText)
        let processedCaption = addStylusInboxTag(to: processedCaptionText)
        let lineToAppend = if captionText.isEmpty {
            "- TODO **\(timeString)** #stylus-inbox\ncollapsed:: true\n    - \(imageMarkdown)\n"
        } else {
            "- TODO **\(timeString)** \(processedCaption)\ncollapsed:: true\n    - \(imageMarkdown)\n"
        }

        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

    /// Internal for reuse and testing from the test target.
    func saveFileWithUniqueFilename(data: Data, baseFileName: String, assetsURL: URL) async throws -> String {
        var fileName = baseFileName
        var assetFilePath = assetsURL.appendingPathComponent(fileName).path
        var retryCount = 0

        while retryCount < Self.maxFileNameRetries {
            do {
                try await journalWriter.saveImageFile(data: data, to: assetFilePath)
                return fileName
            } catch let error as ImageFileError where error == .fileAlreadyExists(assetFilePath) {
                // Generate a unique filename by appending a random string
                let randomSuffix = UUID().uuidString.prefix(Self.uuidSuffixLength)
                let fileURL = URL(fileURLWithPath: baseFileName)
                let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
                let fileExtension = fileURL.pathExtension

                fileName = if fileExtension.isEmpty {
                    "\(nameWithoutExtension)_\(randomSuffix)"
                } else {
                    "\(nameWithoutExtension)_\(randomSuffix).\(fileExtension)"
                }

                assetFilePath = assetsURL.appendingPathComponent(fileName).path
                retryCount += 1
            } catch {
                // Re-throw any other errors
                throw error
            }
        }

        throw FileNameGenerationError.maxRetriesExceeded(fileName: baseFileName, attempts: Self.maxFileNameRetries)
    }

    /// Internal for reuse and testing from the test target.
    func handleDocumentMessage(fileId: String, fileName: String?, caption: String?, timeString: String, filePath: String) async throws {
        let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent("assets")
        try await journalWriter.ensureDirectoryExists(at: assetsURL.path)

        let (fileData, filePathInfo) = try await bot.loadFile(with: fileId)
        let fileExtension = URL(fileURLWithPath: filePathInfo).pathExtension
        let baseFileName = if let fileName, !fileName.isEmpty {
            fileName
        } else if !fileExtension.isEmpty {
            "\(fileId).\(fileExtension)"
        } else {
            fileId
        }
        let finalFileName = try await saveFileWithUniqueFilename(
            data: fileData,
            baseFileName: baseFileName,
            assetsURL: assetsURL,
        )

        let finalFileExtension = URL(fileURLWithPath: finalFileName).pathExtension.lowercased()
        let isPDF = finalFileExtension == "pdf"
        let documentMarkdown = if isPDF {
            "![\(finalFileName)](../assets/\(finalFileName))"
        } else {
            "[\(finalFileName)](../assets/\(finalFileName))"
        }

        let captionText = caption ?? ""
        let processedCaptionText = await linkProcessor.processLinks(in: captionText)
        let processedCaption = addStylusInboxTag(to: processedCaptionText)
        let lineToAppend = if captionText.isEmpty {
            "- TODO **\(timeString)** #stylus-inbox\ncollapsed:: true\n    - \(documentMarkdown)\n"
        } else {
            "- TODO **\(timeString)** \(processedCaption)\ncollapsed:: true\n    - \(documentMarkdown)\n"
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
                    try await handleImageMessage(
                        fileId: fileId,
                        caption: caption,
                        timeString: timeString,
                        filePath: filePath,
                    )
                } catch {
                    print("Error processing image err: \(error)")
                    continue
                }

            case let .document(fileId, fileName, caption):
                do {
                    try await handleDocumentMessage(
                        fileId: fileId,
                        fileName: fileName,
                        caption: caption,
                        timeString: timeString,
                        filePath: filePath,
                    )
                } catch {
                    print("Error processing document err: \(error)")
                    continue
                }
            }

            print("Successfully added to journal: \(filePath)")
            bot.respondAsSaved(on: message)
        }
        fatalError("Bot stream terminated unexpectedly. The bot should run continuously unless explicitly stopped.")
    }
}
