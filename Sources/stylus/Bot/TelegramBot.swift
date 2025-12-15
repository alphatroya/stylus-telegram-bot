import Foundation
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
    }

    // MARK: Functions

    func launch() -> AsyncThrowingStream<Message, Swift.Error> {
        AsyncThrowingStream { continuation in
            DispatchQueue.global().async {
                while let update = self.bot.nextUpdateSync() {
                    guard let message = update.message, let from = message.from else {
                        print("Skipping update - missing message or sender information")
                        continue
                    }

                    if let photo = message.photo, let bestQualityPhoto = self.bestQualityPhotos(from: photo) {
                        continuation
                            .yield(
                                Message(
                                    id: message.messageId,
                                    from: .init(id: from.id, name: from.username),
                                    date: message.date,
                                    messageType: .image(
                                        fileId: bestQualityPhoto,
                                        caption: message.caption,
                                    ),
                                ),
                            )
                    }

                    if let text = message.text {
                        continuation
                            .yield(
                                Message(
                                    id: message.messageId,
                                    from: .init(id: from.id, name: from.username),
                                    date: message.date,
                                    messageType: .justText(text),
                                ),
                            )
                    }
                }
                if let error = self.bot.lastError {
                    continuation.finish(throwing: Error.dataTaskError(error))
                } else {
                    continuation.finish()
                }
            }
        }
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
