import Foundation

// MARK: - OffsetManager

/// Manages persistent storage of the last processed Telegram update offset.
/// This ensures messages are not reprocessed between bot executions.
struct OffsetManager {
    // MARK: Properties

    private let fileWorker: FileWorker

    // MARK: Lifecycle

    init(fileWorker: FileWorker = RealFileWorker()) {
        self.fileWorker = fileWorker
    }

    // MARK: Functions

    /// Returns the path to the offset file, stored alongside the config file.
    private func offsetFilePath() -> String {
        let configPath = ConfigPath.path
        let configURL = URL(fileURLWithPath: configPath)
        let configDirectory = configURL.deletingLastPathComponent()
        return configDirectory.appendingPathComponent("offset.txt").path
    }

    /// Reads the last processed offset from disk.
    /// Returns nil if file doesn't exist or contains invalid data.
    func readOffset() -> Int64? {
        let path = offsetFilePath()
        guard fileWorker.fileExists(at: path) else {
            return nil
        }

        do {
            guard let content = try fileWorker.contents(at: path) else {
                return nil
            }
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int64(trimmedContent)
        } catch {
            print("Warning: Failed to read offset file: \(error)")
            return nil
        }
    }

    /// Writes the offset to disk.
    func writeOffset(_ offset: Int64) throws {
        let path = offsetFilePath()
        let content = "\(offset)\n"
        try fileWorker.writeStringToFile(
            content: content,
            path: path,
            atomically: true,
            encoding: .utf8
        )
    }
}
