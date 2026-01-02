import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@preconcurrency import TelegramBotSDK

// MARK: - TelegramConfig

struct TelegramConfig {
    var token: String
}

// MARK: - TelegramBot

final class TelegramBot: Bot, @unchecked Sendable {
    // MARK: Nested Types

    enum Error: Swift.Error {
        case dataTaskError(TelegramBotSDK.DataTaskError)
        case unknownError
        case wrongFileURL
    }

    // MARK: Properties

    let bot: TelegramBotSDK.TelegramBot

    // MARK: Lifecycle

    init(config: TelegramConfig) {
        bot = TelegramBotSDK.TelegramBot(token: config.token)
        bot.logger = {
            #if DEBUG
                print($0)
            #endif
        }
    }

    // MARK: Functions

    func fetchAllMessages(startingOffset: Int64?) async throws -> (messages: [Message], nextOffset: Int64?) {
        var allMessages: [Message] = []
        var currentOffset = startingOffset
        let batchLimit = 100 // Telegram API limit

        print("Starting message fetch with offset: \(currentOffset?.description ?? "nil")")

        while true {
            let updates = bot.getUpdatesSync(
                offset: currentOffset,
                limit: batchLimit,
                timeout: 0, // No timeout - return immediately with available messages
            )

            // Check for API errors
            if let error = bot.lastError {
                throw Error.dataTaskError(error)
            }

            guard let updates, !updates.isEmpty else {
                // No more messages available
                break
            }

            print("Fetched \(updates.count) updates in this batch")

            // Process each update and convert to Message objects
            for update in updates {
                guard let message = update.message, let from = message.from else {
                    print("Skipping update \(update.updateId) - missing message or sender information")
                    currentOffset = update.updateId + 1
                    continue
                }

                let processedMessage = processMessage(message, from: from, updateId: update.updateId)
                if let processedMessage {
                    allMessages.append(processedMessage)
                }

                // Update offset to next unprocessed message
                currentOffset = update.updateId + 1
            }
        }

        print("Completed message fetch. Total messages: \(allMessages.count)")
        return (messages: allMessages, nextOffset: currentOffset)
    }

    func respondAsSaved(on message: Message) {
        bot.sendMessageSync(
            chatId: .chat(message.from.id),
            text: "✅ Saved!",
            replyToMessageId: message.id,
        )
    }

    @concurrent
    func loadFile(with id: String) async throws -> (data: Data, filePath: String) {
        let filePath: String = try await withCheckedThrowingContinuation { continuation in
            bot.getFileAsync(fileId: id) { result, err in
                if let err {
                    continuation.resume(throwing: Error.dataTaskError(err))
                    return
                }
                if let result, let filePath = result.filePath {
                    continuation.resume(returning: filePath)
                    return
                }
                continuation.resume(throwing: Error.unknownError)
            }
        }
        guard let url = URL(string: "https://api.telegram.org/file/bot\(bot.token)/\(filePath)") else {
            throw Error.wrongFileURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return (data: data, filePath: filePath)
    }

    private func processMessage(
        _ message: TelegramBotSDK.Message,
        from: TelegramBotSDK.User,
        updateId: Int64,
    ) -> Message? {
        let (originalSender, messageContext) = extractOriginalSender(from: message)

        if let document = message.document {
            return handleDocumentMessage(
                message,
                from: from,
                document: document,
                originalSender: originalSender,
                messageContext: messageContext,
                updateId: updateId,
            )
        }

        if let photo = message.photo, let bestQualityPhoto = bestQualityPhotos(from: photo) {
            return handlePhotoMessage(
                message,
                from: from,
                fileId: bestQualityPhoto,
                originalSender: originalSender,
                messageContext: messageContext,
                updateId: updateId,
            )
        }

        if let text = message.text {
            return handleTextMessage(
                message,
                from: from,
                text: text,
                originalSender: originalSender,
                messageContext: messageContext,
                updateId: updateId,
            )
        }

        return nil
    }

    private func extractOriginalSender(from message: TelegramBotSDK.Message) -> (Message.From?, Message.MessageContext) {
        // Priority: reply over forward
        // Skip reply chains - only handle direct replies (ignore replies to replies)
        if let replyToMessage = message.replyToMessage,
           replyToMessage.replyToMessage == nil, // Not a reply chain
           let originalUser = replyToMessage.from,
           originalUser.isBot != true // Skip bot messages
        {
            let sender = Message.From(
                id: originalUser.id,
                name: originalUser.username,
                firstName: originalUser.firstName,
                lastName: originalUser.lastName,
            )
            return (sender, .reply)
        }

        // Check for forwarded messages
        if let forwardFrom = message.forwardFrom {
            let sender = Message.From(
                id: forwardFrom.id,
                name: forwardFrom.username,
                firstName: forwardFrom.firstName,
                lastName: forwardFrom.lastName,
            )
            return (sender, .forward)
        }

        return (nil, .original)
    }

    private func handleDocumentMessage(
        _ message: TelegramBotSDK.Message,
        from: TelegramBotSDK.User,
        document: TelegramBotSDK.Document,
        originalSender: Message.From?,
        messageContext: Message.MessageContext,
        updateId: Int64,
    ) -> Message {
        Message(
            id: message.messageId,
            updateId: updateId,
            from: .init(id: from.id, name: from.username, firstName: from.firstName, lastName: from.lastName),
            date: message.date,
            messageType: .document(
                fileId: document.fileId,
                fileName: document.fileName,
                caption: message.caption,
            ),
            originalSender: originalSender,
            messageContext: messageContext,
        )
    }

    private func handlePhotoMessage(
        _ message: TelegramBotSDK.Message,
        from: TelegramBotSDK.User,
        fileId: String,
        originalSender: Message.From?,
        messageContext: Message.MessageContext,
        updateId: Int64,
    ) -> Message {
        Message(
            id: message.messageId,
            updateId: updateId,
            from: .init(id: from.id, name: from.username, firstName: from.firstName, lastName: from.lastName),
            date: message.date,
            messageType: .image(
                fileId: fileId,
                caption: message.caption,
            ),
            originalSender: originalSender,
            messageContext: messageContext,
        )
    }

    private func handleTextMessage(
        _ message: TelegramBotSDK.Message,
        from: TelegramBotSDK.User,
        text: String,
        originalSender: Message.From?,
        messageContext: Message.MessageContext,
        updateId: Int64,
    ) -> Message {
        Message(
            id: message.messageId,
            updateId: updateId,
            from: .init(id: from.id, name: from.username, firstName: from.firstName, lastName: from.lastName),
            date: message.date,
            messageType: .justText(text),
            originalSender: originalSender,
            messageContext: messageContext,
        )
    }

    private func bestQualityPhotos(from photos: [PhotoSize]) -> String? {
        photos.max { photo1, photo2 in
            if let size1 = photo1.fileSize, let size2 = photo2.fileSize {
                return size1 < size2
            }
            let area1 = photo1.width * photo1.height
            let area2 = photo2.width * photo2.height
            return area1 < area2
        }?.fileId
    }
}
