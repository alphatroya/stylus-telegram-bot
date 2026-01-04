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

// MARK: - MessageHandler

protocol MessageHandler {
    func handleMessageType(
        _ messageType: Message.MessageType,
        timeString: String,
        filePath: String,
        originalSender: Message.From?,
    ) async
}

// MARK: - DefaultMessageHandler

struct DefaultMessageHandler: MessageHandler {
    // MARK: Static Properties

    // MARK: Constants

    private static let uuidSuffixLength = 8
    private static let maxFileNameRetries = 100

    // MARK: Properties

    let config: Config
    let journalWriter: JournalWriter
    let linkProcessor: LinkProcessor
    let bot: Bot

    // MARK: Functions

    func handleJustTextMessage(
        text: String, timeString: String, filePath: String, originalSender: Message.From? = nil,
    ) async throws {
        let processedText = await linkProcessor.processLinks(in: text)
        var taggedText = processedText

        // Add user tag if there's an original sender
        if let originalSender, let userName = extractUserName(from: originalSender) {
            taggedText = addUserTag(to: taggedText, userName: userName)
        }

        // Add stylus-inbox tag
        taggedText = addStylusInboxTag(to: taggedText)

        let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"
        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

    func handleImageMessage(
        fileId: String,
        caption: String?,
        timeString: String,
        filePath: String,
        originalSender: Message.From? = nil,
    ) async throws {
        let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent(
            "assets")
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

        var processedCaption = processedCaptionText

        // Add user tag if there's an original sender and caption exists
        if !captionText.isEmpty, let originalSender,
           let userName = extractUserName(from: originalSender)
        {
            processedCaption = addUserTag(to: processedCaption, userName: userName)
        }

        // Add stylus-inbox tag if caption exists
        if !captionText.isEmpty {
            processedCaption = addStylusInboxTag(to: processedCaption)
        }

        let lineToAppend = formatMediaEntry(
            timeString: timeString,
            caption: captionText.isEmpty ? "" : processedCaption,
            mediaMarkdown: imageMarkdown,
            originalSender: originalSender,
        )

        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

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

                fileName =
                    if fileExtension.isEmpty {
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

        throw FileNameGenerationError.maxRetriesExceeded(
            fileName: baseFileName, attempts: Self.maxFileNameRetries,
        )
    }

    func handleDocumentMessage(
        fileId: String,
        fileName: String?,
        caption: String?,
        timeString: String,
        filePath: String,
        originalSender: Message.From? = nil,
    ) async throws {
        let assetsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent(
            "assets")
        try await journalWriter.ensureDirectoryExists(at: assetsURL.path)

        let (fileData, filePathInfo) = try await bot.loadFile(with: fileId)
        let fileExtension = URL(fileURLWithPath: filePathInfo).pathExtension

        // Sanitize fileName to prevent path traversal attacks
        let preferredFileName: String
        if let fileName, !fileName.isEmpty {
            // Use only the last path component to avoid directory traversal (e.g., "../../secret")
            let baseName = (fileName as NSString).lastPathComponent
            if baseName.isEmpty || baseName == "." || baseName == ".." {
                preferredFileName = ""
            } else {
                preferredFileName = baseName
            }
        } else {
            preferredFileName = ""
        }

        let baseFileName =
            if !preferredFileName.isEmpty {
                preferredFileName
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
        let documentMarkdown =
            if isPDF {
                "![\(finalFileName)](../assets/\(finalFileName))"
            } else {
                "[\(finalFileName)](../assets/\(finalFileName))"
            }

        let captionText = caption ?? ""
        let processedCaptionText = await linkProcessor.processLinks(in: captionText)

        var processedCaption = processedCaptionText

        // Add user tag if there's an original sender and caption exists
        if !captionText.isEmpty, let originalSender,
           let userName = extractUserName(from: originalSender)
        {
            processedCaption = addUserTag(to: processedCaption, userName: userName)
        }

        // Add stylus-inbox tag if caption exists
        if !captionText.isEmpty {
            processedCaption = addStylusInboxTag(to: processedCaption)
        }

        let lineToAppend = formatMediaEntry(
            timeString: timeString,
            caption: captionText.isEmpty ? "" : processedCaption,
            mediaMarkdown: documentMarkdown,
            originalSender: originalSender,
        )

        try await journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }

    func handleMessageType(
        _ messageType: Message.MessageType,
        timeString: String,
        filePath: String,
        originalSender: Message.From?,
    ) async {
        switch messageType {
        case let .justText(text):
            do {
                try await handleJustTextMessage(
                    text: text, timeString: timeString, filePath: filePath,
                    originalSender: originalSender,
                )
            } catch {
                print("Error processing message: \(text), err: \(error)")
            }

        case let .image(fileId, caption):
            do {
                try await handleImageMessage(
                    fileId: fileId,
                    caption: caption,
                    timeString: timeString,
                    filePath: filePath,
                    originalSender: originalSender,
                )
            } catch {
                print("Error processing image err: \(error)")
            }

        case let .document(fileId, fileName, caption):
            do {
                try await handleDocumentMessage(
                    fileId: fileId,
                    fileName: fileName,
                    caption: caption,
                    timeString: timeString,
                    filePath: filePath,
                    originalSender: originalSender,
                )
            } catch {
                print("Error processing document err: \(error)")
            }
        }
    }

    /// Helper method to format media entry with optional caption and user tag
    private func formatMediaEntry(
        timeString: String,
        caption: String,
        mediaMarkdown: String,
        originalSender: Message.From?,
    ) -> String {
        if caption.isEmpty {
            if let originalSender, let userName = extractUserName(from: originalSender) {
                let userTag = createUserTag(from: userName)
                return
                    "- TODO **\(timeString)** \(userTag) #stylus-inbox\ncollapsed:: true\n    - \(mediaMarkdown)\n"
            } else {
                return
                    "- TODO **\(timeString)** #stylus-inbox\ncollapsed:: true\n    - \(mediaMarkdown)\n"
            }
        } else {
            return "- TODO **\(timeString)** \(caption)\ncollapsed:: true\n    - \(mediaMarkdown)\n"
        }
    }
}
