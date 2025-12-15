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
        case image(fileId: String, caption: String?)
    }

    // MARK: Properties

    var id: ID
    var from: From
    var date: Date
    var messageType: MessageType
}

// MARK: - Bot

protocol Bot {
    typealias File = Data

    func launch() -> AsyncThrowingStream<Message, Error>
    func respondAsSaved(on: Message)
    func loadFile(with: String) async throws -> File
    func getFilePath(for fileId: String) async throws -> String
}
