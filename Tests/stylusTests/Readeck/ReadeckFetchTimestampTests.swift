import Foundation
@testable import stylus
import Testing

@Suite("ReadeckFetchTimestamp Tests")
struct ReadeckFetchTimestampTests {
    // MARK: Read Tests

    @Test
    func `Read returns nil when no file exists`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        let result = manager.readLastFetch()

        #expect(result == nil)
    }

    @Test
    func `Read returns timestamp when file exists`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        try manager.writeLastFetch("2025-06-15T14:30:00Z")

        let result = manager.readLastFetch()
        #expect(result == "2025-06-15T14:30:00Z")
    }

    @Test
    func `File is created in correct location`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        try manager.writeLastFetch("2025-01-01T00:00:00Z")

        let expectedPath = tempDir.appendingPathComponent("readeck_last_fetch.txt").path
        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }

    // MARK: Atomic Write Tests

    @Test
    func `Atomic update prevents corruption`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)

        try manager.writeLastFetch("2025-01-01T00:00:00Z")
        try manager.writeLastFetch("2025-06-15T14:30:00Z")

        let result = manager.readLastFetch()
        #expect(result == "2025-06-15T14:30:00Z")

        // No temp files remain
        let tempFilePath = tempDir.appendingPathComponent("readeck_last_fetch.txt.tmp").path
        #expect(!FileManager.default.fileExists(atPath: tempFilePath))
    }

    // MARK: Edge Cases

    @Test
    func `Read empty file returns nil`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("readeck_last_fetch.txt")
        try "".write(to: filePath, atomically: false, encoding: .utf8)

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        #expect(manager.readLastFetch() == nil)
    }

    @Test
    func `Read whitespace-only file returns nil`() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("readeck_last_fetch.txt")
        try "  \n\t  \n".write(to: filePath, atomically: false, encoding: .utf8)

        let manager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        #expect(manager.readLastFetch() == nil)
    }

    // MARK: Helpers

    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("stylus-readeck-timestamp-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
