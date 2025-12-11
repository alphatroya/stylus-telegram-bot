import Foundation

// MARK: - Message

struct Message {
    // MARK: Nested Types

    struct From {
        let id: Int64
        let name: String?
    }

    typealias ID = Int

    enum MessageType {
        case justText(String)
    }

    // MARK: Properties

    var id: ID
    var from: From
    var date: Date
    var messageType: MessageType
}

// MARK: - Bot

protocol Bot {
    func launch() -> AsyncThrowingStream<Message, Error>
    func respondAsSaved(on: Message)
}
