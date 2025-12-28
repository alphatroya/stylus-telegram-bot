import Foundation

// MARK: - Message

struct Message {
    // MARK: Nested Types

    struct From {
        let id: Int64
        let name: String?
    }

    typealias MessageID = Int

    enum MessageType {
        case justText(String)
        case image(fileId: String, caption: String?)
        case document(fileId: String, fileName: String?, caption: String?)
    }

    // MARK: Properties

    var id: MessageID
    var from: From
    var date: Date
    var messageType: MessageType
}

// MARK: - Bot

protocol Bot {
    typealias File = Data

    func fetchPendingMessages(startingOffset: Int64?) async throws -> (messages: [Message], nextOffset: Int64?)
    func respondAsSaved(on message: Message)
    func loadFile(with: String) async throws -> (data: File, filePath: String)
}
