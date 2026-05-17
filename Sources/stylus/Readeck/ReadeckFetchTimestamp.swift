import Foundation

// MARK: - ReadeckFetchTimestampError

enum ReadeckFetchTimestampError: Error, LocalizedError {
    case invalidTimestampData(String)
    case writeFailure(Error)
    case atomicUpdateFailure(Error)

    // MARK: Computed Properties

    var errorDescription: String? {
        switch self {
        case let .invalidTimestampData(content):
            "Invalid timestamp data: '\(content)'"
        case let .writeFailure(error):
            "Failed to write Readeck fetch timestamp: \(error.localizedDescription)"
        case let .atomicUpdateFailure(error):
            "Failed to atomically update Readeck fetch timestamp: \(error.localizedDescription)"
        }
    }
}

// MARK: - ReadeckFetchTimestamp

/// Manages the last successful Readeck sync timestamp.
///
/// Follows the same pattern as `OffsetManager`: stores an ISO 8601 timestamp string
/// in a text file alongside the config file, with atomic writes to prevent corruption.
struct ReadeckFetchTimestamp {
    // MARK: Properties

    private let timestampFilePath: String
    private let fileManager: FileManager

    // MARK: Lifecycle

    init(configDirectory: String? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if let configDirectory {
            timestampFilePath = URL(fileURLWithPath: configDirectory)
                .appendingPathComponent("readeck_last_fetch.txt")
                .path
        } else {
            let configPath = ConfigPath.path
            let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent()
            timestampFilePath = configDir.appendingPathComponent("readeck_last_fetch.txt").path
        }
    }

    // MARK: Functions

    /// Reads the last fetch timestamp. Returns nil if no timestamp is stored (first run).
    func readLastFetch() -> String? {
        guard fileManager.fileExists(atPath: timestampFilePath) else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: timestampFilePath, encoding: .utf8)
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedContent.isEmpty else {
                return nil
            }

            return trimmedContent
        } catch {
            print("Warning: Could not read Readeck timestamp file at \(timestampFilePath): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes the fetch timestamp atomically to prevent corruption.
    ///
    /// - Parameter timestamp: ISO 8601 formatted timestamp string.
    func writeLastFetch(_ timestamp: String) throws {
        let timestampString = "\(timestamp)\n"
        let tempFilePath = timestampFilePath + ".tmp"

        do {
            let timestampDir = URL(fileURLWithPath: timestampFilePath).deletingLastPathComponent()
            try fileManager.createDirectory(at: timestampDir, withIntermediateDirectories: true)

            try timestampString.write(toFile: tempFilePath, atomically: false, encoding: .utf8)

            _ = try fileManager.replaceItem(
                at: URL(fileURLWithPath: timestampFilePath),
                withItemAt: URL(fileURLWithPath: tempFilePath),
                backupItemName: nil,
                options: [],
                resultingItemURL: nil,
            )
        } catch {
            try? fileManager.removeItem(atPath: tempFilePath)
            throw ReadeckFetchTimestampError.atomicUpdateFailure(error)
        }
    }
}
