import Foundation
import TelegramBotSDK

// MARK: - JournalEntryProcessorProtocol

protocol JournalEntryProcessorProtocol {
    func handleTextMessage(
        _ message: TelegramBotSDK.Message,
        text: String,
        journalsPath: String,
    ) async throws
}

// MARK: - JournalEntryProcessor

struct JournalEntryProcessor: JournalEntryProcessorProtocol {
    // MARK: Properties

    private let journalWriter: JournalWriter
    private let linkProcessor: LinkProcessor
    private let dateFormatter: StylusDateFormatter


    // MARK: Initialization

    init(
        journalWriter: JournalWriter = .init(),
        linkProcessor: LinkProcessor = .init(),
        dateFormatter: StylusDateFormatter = .init(),
    ) {
        self.journalWriter = journalWriter
        self.linkProcessor = linkProcessor
        self.dateFormatter = dateFormatter
    }

    // MARK: Functions

    func handleTextMessage(
        _ message: TelegramBotSDK.Message,
        text: String,
        journalsPath: String,
    ) async throws {
        let messageDateFormatted = await dateFormatter.formatDate("yyyy_MM_dd", date: message.date)
        let filePath = (journalsPath as NSString).appendingPathComponent("\(messageDateFormatted).md")

        let timeString = await dateFormatter.formatDate("HH:mm", date: message.date)

        // Process links first
        let processedText = await linkProcessor.processLinks(in: text)
        let taggedText = addStylusInboxTag(to: processedText)
        let lineToAppend = "- TODO **\(timeString)** \(taggedText)\n"

        try journalWriter.appendToJournalFile(at: filePath, content: lineToAppend)
    }
}
