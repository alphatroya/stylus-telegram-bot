import Foundation

// MARK: - FileHandleProtocol

protocol FileHandleProtocol {
    func seekToEndOfFile() -> UInt64
    func write(_ data: Data)
    func closeFile()
}

// MARK: - FileHandle + FileHandleProtocol

extension FileHandle: FileHandleProtocol {}

// MARK: - FileWorker

struct FileWorker: Sendable {
    // MARK: Static Properties

    static let system: FileWorker = .init()

    // MARK: Properties

    var homeDirectoryPath: @Sendable () -> String = {
        ProcessInfo.processInfo.environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    var fileExistsAtPath: @Sendable (String) -> Bool = {
        FileManager.default.fileExists(atPath: $0)
    }

    var createDirectoryAtPath: @Sendable (String, Bool, [FileAttributeKey: Any]?) throws
        -> Void = { path, createIntermediates, attributes in
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: createIntermediates,
                attributes: attributes,
            )
        }

    var contentsAtPath: @Sendable (String) throws -> String? = { path in
        try String(contentsOfFile: path, encoding: .utf8)
    }

    var writeStringToFile: @Sendable (String, String, Bool, String.Encoding) throws -> Void = {
        content, path, atomically, encoding in
        try content.write(toFile: path, atomically: atomically, encoding: encoding)
    }

    var fileHandleForWritingToPath: @Sendable (String) throws -> FileHandleProtocol = { path in
        try FileHandle(forWritingTo: URL(fileURLWithPath: path))
    }
}
