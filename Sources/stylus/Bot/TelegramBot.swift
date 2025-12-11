import Foundation
@preconcurrency import TelegramBotSDK

// MARK: - TelegramConfig

struct TelegramConfig {
    var token: String
}

// MARK: - TelegramBot

final class TelegramBot: Bot, @unchecked Sendable {
    // MARK: Nested Types

    struct Error: Swift.Error {
        var dataTaskError: TelegramBotSDK.DataTaskError
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
                    guard let text = message.text else {
                        print("Skipping update - message has no text content")
                        continue
                    }

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
                if let error = self.bot.lastError {
                    continuation.finish(throwing: Error(dataTaskError: error))
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
}
