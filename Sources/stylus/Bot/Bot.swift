import Foundation

// MARK: - Message

struct Message {
    // MARK: Nested Types

    struct From {
        let id: Int64
        let name: String?
        let firstName: String?
        let lastName: String?
    }

    typealias MessageID = Int

    enum MessageType {
        case justText(String)
        case image(fileId: String, caption: String?)
        case document(fileId: String, fileName: String?, caption: String?)
    }

    enum MessageContext {
        case original
        case reply
        case forward
    }

    // MARK: Properties

    var id: MessageID
    var from: From
    var date: Date
    var messageType: MessageType
    var originalSender: From?
    var messageContext: MessageContext
}

// MARK: - Bot

protocol Bot {
    typealias File = Data

    func launch() -> AsyncThrowingStream<Message, Error>
    func respondAsSaved(on message: Message)
    func loadFile(with: String) async throws -> (data: File, filePath: String)
}
