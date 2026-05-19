import Foundation

// MARK: - App

struct App {
    // MARK: Properties

    var config: Config
    var journalWriter: JournalWriter = .init()
    var linkProcessor: LinkProcessor = .init()
    var dateFormatter: StylusDateFormatter = .init()
    var bot: Bot
    var offsetManager: OffsetManager = .init()
    var messageHandler: MessageHandler

    // MARK: Functions

    func run() async throws {
        print("🚀 Starting stylus bot with one-shot execution model")

        let journalsURL = URL(fileURLWithPath: config.knowledgeBaseLocation).appendingPathComponent(
            "journals",
        )
        try await journalWriter.ensureDirectoryExists(at: journalsURL.path)

        // Read offset state
        let startOffset = offsetManager.readOffsetSafely()
        if let startOffset {
            print("📋 Resuming from offset: \(startOffset)")
        } else {
            print("📋 Starting fresh (no previous offset found)")
        }

        // Fetch all pending messages
        let (messages, nextOffset) = try await bot.fetchAllMessages(startingOffset: startOffset)
        print("📥 Fetched \(messages.count) messages to process")

        if messages.isEmpty {
            print("✅ No messages to process, exiting cleanly")
            return
        }

        // Process each message
        var processedCount = 0

        for message in messages {
            do {
                try await processMessage(message, journalsURL: journalsURL)
                processedCount += 1
                print("✅ Processed message \(processedCount)/\(messages.count)")
            } catch {
                print("❌ Error processing message \(message.id): \(error.localizedDescription)")
                // Continue processing other messages
            }
        }

        // Update offset after successful processing
        if let nextOffset {
            do {
                try offsetManager.writeOffset(nextOffset)
                print("💾 Updated offset to: \(nextOffset)")
            } catch {
                print("⚠️  Failed to update offset: \(error.localizedDescription)")
                // This is not fatal - the bot can still continue
            }
        }

        print(
            "🎉 Processing complete! Processed \(processedCount)/\(messages.count) messages successfully",
        )
    }

    private func processMessage(_ message: Message, journalsURL: URL) async throws {
        guard message.from.id == config.telegramUserID else {
            print("Wrong user sent a message, \(message.from.id) - \(message.from.name ?? "NONE")")
            return
        }

        let messageDateFormatted = await dateFormatter.formatDate("yyyy_MM_dd", date: message.date)
        let filePath = journalsURL.appendingPathComponent("\(messageDateFormatted).md").path
        let timeString = await dateFormatter.formatDate("HH:mm", date: message.date)

        await messageHandler.handleMessageType(
            message.messageType, timeString: timeString, filePath: filePath,
            originalSender: message.originalSender,
        )

        print("Successfully added to journal: \(filePath)")
        bot.respondAsSaved(on: message)
    }
}
