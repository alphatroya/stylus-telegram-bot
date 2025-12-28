import Foundation
@preconcurrency import TelegramBotSDK
import CCurl

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

    // MARK: Constants

    private static let batchSize = 100
    private static let maxRetries = 3
    private static let baseRetryDelay = 1.0

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

    /// Fetches all pending messages from Telegram using pagination.
    /// Returns when there are no more pending messages.
    ///
    /// - Parameter startingOffset: The offset to start fetching from. If nil, starts from the beginning.
    /// - Returns: A tuple containing all fetched messages and the next offset to use for subsequent calls.
    func fetchPendingMessages(startingOffset: Int64?) async throws -> (messages: [Message], nextOffset: Int64?) {
        var allMessages: [Message] = []
        var currentOffset = startingOffset
        var retryCount = 0
        
        while true {
            // Use timeout=0 for immediate return (no long polling)
            let updates = bot.getUpdatesSync(offset: currentOffset, limit: Self.batchSize, timeout: 0)
            
            // Handle errors with retry logic
            if updates == nil {
                if let error = bot.lastError {
                    // Check if this is a temporary error we should retry
                    if case .libcurlError(let code, _) = error {
                        switch code {
                        case CURLE_COULDNT_RESOLVE_PROXY, CURLE_COULDNT_RESOLVE_HOST, 
                             CURLE_COULDNT_CONNECT, CURLE_OPERATION_TIMEDOUT, 
                             CURLE_SSL_CONNECT_ERROR, CURLE_SEND_ERROR, CURLE_RECV_ERROR:
                            retryCount += 1
                            if retryCount <= Self.maxRetries {
                                let delay = Self.baseRetryDelay * Double(retryCount)
                                print("Temporary network error, retrying in \(delay)s... (attempt \(retryCount)/\(Self.maxRetries))")
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                continue
                            }
                        default:
                            break
                        }
                    }
                    throw Error.dataTaskError(error)
                }
                throw Error.unknownError
            }
            
            guard let updates, !updates.isEmpty else {
                // No more updates available
                break
            }
            
            // Reset retry count on successful fetch
            retryCount = 0
            
            // Process all updates in this batch
            for update in updates {
                if let message = update.message, let from = message.from {
                    if let convertedMessage = convertMessage(message, from: from) {
                        allMessages.append(convertedMessage)
                    }
                }
                
                // Update offset to skip this update in next fetch
                let nextUpdateId = update.updateId + 1
                if let current = currentOffset {
                    currentOffset = max(current, nextUpdateId)
                } else {
                    currentOffset = nextUpdateId
                }
            }
        }
        
        return (messages: allMessages, nextOffset: currentOffset)
    }

    func respondAsSaved(on message: Message) {
        bot.sendMessageAsync(
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

    private func convertMessage(
        _ message: TelegramBotSDK.Message,
        from: TelegramBotSDK.User
    ) -> Message? {
        var messageType: Message.MessageType?

        if let document = message.document {
            messageType = .document(
                fileId: document.fileId,
                fileName: document.fileName,
                caption: message.caption
            )
        } else if let photo = message.photo, let bestQualityPhoto = bestQualityPhotos(from: photo) {
            messageType = .image(
                fileId: bestQualityPhoto,
                caption: message.caption
            )
        } else if let text = message.text {
            messageType = .justText(text)
        }

        guard let messageType else {
            print("Skipping message - no supported content type")
            return nil
        }

        return Message(
            id: message.messageId,
            from: .init(id: from.id, name: from.username),
            date: message.date,
            messageType: messageType
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
