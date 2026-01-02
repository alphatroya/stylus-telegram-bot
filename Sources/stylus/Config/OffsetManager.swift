import Foundation

// MARK: - OffsetManagerError

enum OffsetManagerError: Error, LocalizedError {
    case invalidOffsetData(String)
    case writeFailure(Error)
    case atomicUpdateFailure(Error)

    // MARK: Computed Properties

    var errorDescription: String? {
        switch self {
        case let .invalidOffsetData(content):
            "Invalid offset data: '\(content)'"
        case let .writeFailure(error):
            "Failed to write offset state: \(error.localizedDescription)"
        case let .atomicUpdateFailure(error):
            "Failed to atomically update offset state: \(error.localizedDescription)"
        }
    }
}

// MARK: - OffsetManager

struct OffsetManager {
    // MARK: Static Properties

    // MARK: Constants

    private static let offsetFileName = "telegram_offset.txt"

    // MARK: Properties

    private let offsetFilePath: String
    private let fileManager: FileManager

    // MARK: Lifecycle

    init(configDirectory: String = ConfigPath.path, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        offsetFilePath = URL(fileURLWithPath: configDirectory)
            .appendingPathComponent(Self.offsetFileName)
            .path
    }

    // MARK: Functions

    /// Reads the stored offset value. Returns nil if no offset is stored or on first run.
    func readOffset() throws -> Int64? {
        guard fileManager.fileExists(atPath: offsetFilePath) else {
            // No offset file exists - this is normal for first run
            return nil
        }

        do {
            let content = try String(contentsOfFile: offsetFilePath, encoding: .utf8)
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedContent.isEmpty else {
                // Empty file - treat as no offset
                return nil
            }
            guard let offset = Int64(trimmedContent) else {
                throw OffsetManagerError.invalidOffsetData(trimmedContent)
            }

            return offset
        } catch let error as OffsetManagerError {
            throw error
        } catch {
            // File read error or other issue - log warning and return nil for graceful fallback
            print("Warning: Could not read offset file at \(offsetFilePath): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes the offset value atomically to prevent corruption.
    func writeOffset(_ offset: Int64) throws {
        let offsetString = "\(offset)\n"
        let tempFilePath = offsetFilePath + ".tmp"

        do {
            // Ensure directory exists
            let offsetDir = URL(fileURLWithPath: offsetFilePath).deletingLastPathComponent()
            try fileManager.createDirectory(at: offsetDir, withIntermediateDirectories: true)

            // Write to temporary file first
            try offsetString.write(toFile: tempFilePath, atomically: false, encoding: .utf8)

            // Atomically move to final location
            _ = try fileManager.replaceItem(
                at: URL(fileURLWithPath: offsetFilePath),
                withItemAt: URL(fileURLWithPath: tempFilePath),
                backupItemName: nil,
                options: [],
                resultingItemURL: nil,
            )
        } catch {
            // Clean up temp file if it exists
            try? fileManager.removeItem(atPath: tempFilePath)
            throw OffsetManagerError.atomicUpdateFailure(error)
        }
    }

    /// Safely reads offset with graceful error handling for corrupted state.
    func readOffsetSafely() -> Int64? {
        do {
            return try readOffset()
        } catch {
            print("Warning: Corrupted offset state detected: \(error.localizedDescription)")
            print("Starting from current messages to avoid processing historical data")
            return nil
        }
    }
}
