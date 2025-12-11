import Foundation

// MARK: - FileHandleProtocol

protocol FileHandleProtocol: Sendable {
    func seekToEndOfFile() -> UInt64
    func write(_ data: Data)
    func closeFile()
}

// MARK: - FileHandle + FileHandleProtocol

extension FileHandle: FileHandleProtocol {}

// MARK: - FileWorker

protocol FileWorker: Sendable {
    func fileExists(at path: String) -> Bool

    func createDirectory(
        at: String,
        createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?,
    ) throws

    func contents(at path: String) throws -> String?

    func writeStringToFile(
        content: String,
        path: String,
        atomically: Bool,
        encoding: String.Encoding,
    ) throws

    func fileHandleForWriting(to path: String) throws -> FileHandleProtocol
}

// MARK: - SystemFileWorker

final class SystemFileWorker: FileWorker, @unchecked Sendable {
    // MARK: Properties

    let fileManager: FileManager

    // MARK: Lifecycle

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: Functions

    func fileExists(at path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    func createDirectory(
        at path: String,
        createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?,
    ) throws {
        try fileManager.createDirectory(
            atPath: path,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes,
        )
    }

    func contents(at path: String) throws -> String? {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    func writeStringToFile(
        content: String,
        path: String,
        atomically: Bool,
        encoding: String.Encoding,
    ) throws {
        try content.write(toFile: path, atomically: atomically, encoding: encoding)
    }

    func fileHandleForWriting(to path: String) throws -> FileHandleProtocol {
        try FileHandle(forWritingTo: URL(fileURLWithPath: path))
    }
}
