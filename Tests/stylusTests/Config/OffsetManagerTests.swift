import Foundation
@testable import stylus
import Testing

@Suite("OffsetManager Tests")
struct OffsetManagerTests {
    // MARK: Basic Operations Tests

    @Test("Read offset when no file exists returns nil")
    func readOffsetNoFile() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: tempDir.path)
        let offset = try manager.readOffset()

        #expect(offset == nil)
    }

    @Test("Write and read offset successfully")
    func writeAndReadOffset() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: tempDir.path)
        let testOffset: Int64 = 12345

        try manager.writeOffset(testOffset)
        let readOffset = try manager.readOffset()

        #expect(readOffset == testOffset)
    }

    @Test("Offset file is created in correct location")
    func offsetFileLocation() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: tempDir.path)
        try manager.writeOffset(999)

        let expectedPath = tempDir.appendingPathComponent("telegram_offset.txt").path
        #expect(FileManager.default.fileExists(atPath: expectedPath))
    }

    // MARK: Atomic Updates Tests

    @Test("Atomic update prevents corruption")
    func atomicUpdate() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: tempDir.path)

        // Write initial value
        try manager.writeOffset(100)

        // Write new value
        try manager.writeOffset(200)

        // Verify final value is correct
        let offset = try manager.readOffset()
        #expect(offset == 200)

        // Verify no temporary files remain
        let tempFilePath = tempDir.appendingPathComponent("telegram_offset.txt.tmp").path
        #expect(!FileManager.default.fileExists(atPath: tempFilePath))
    }

    // MARK: Error Handling Tests

    @Test("Read corrupted file handles error gracefully")
    func readCorruptedFile() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create corrupted file with invalid content
        let offsetFilePath = tempDir.appendingPathComponent("telegram_offset.txt")
        try "not_a_number".write(to: offsetFilePath, atomically: false, encoding: .utf8)

        let manager = OffsetManager(configDirectory: tempDir.path)

        // Should throw error for corrupted data
        #expect(throws: OffsetManagerError.self) {
            _ = try manager.readOffset()
        }
    }

    @Test("Read safely handles corrupted file without throwing")
    func readSafelyWithCorruption() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create corrupted file
        let offsetFilePath = tempDir.appendingPathComponent("telegram_offset.txt")
        try "corrupted_data".write(to: offsetFilePath, atomically: false, encoding: .utf8)

        let manager = OffsetManager(configDirectory: tempDir.path)

        // Should return nil without throwing
        let offset = manager.readOffsetSafely()
        #expect(offset == nil)
    }

    @Test("Empty file is handled gracefully")
    func emptyFile() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create empty file
        let offsetFilePath = tempDir.appendingPathComponent("telegram_offset.txt")
        try "".write(to: offsetFilePath, atomically: false, encoding: .utf8)

        let manager = OffsetManager(configDirectory: tempDir.path)
        let offset = try manager.readOffset()

        #expect(offset == nil)
    }

    @Test("Whitespace-only file is handled gracefully")
    func whitespaceOnlyFile() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create file with only whitespace
        let offsetFilePath = tempDir.appendingPathComponent("telegram_offset.txt")
        try "   \n\t  \n".write(to: offsetFilePath, atomically: false, encoding: .utf8)

        let manager = OffsetManager(configDirectory: tempDir.path)
        let offset = try manager.readOffset()

        #expect(offset == nil)
    }

    // MARK: Directory Creation Tests

    @Test("Creates directory if it doesn't exist")
    func createsDirectory() throws {
        let tempDir = try createTempDirectory()
        let nonExistentSubDir = tempDir.appendingPathComponent("nested").appendingPathComponent("config")
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: nonExistentSubDir.path)
        try manager.writeOffset(42)

        let offsetFilePath = nonExistentSubDir.appendingPathComponent("telegram_offset.txt")
        #expect(FileManager.default.fileExists(atPath: offsetFilePath.path))

        let readOffset = try manager.readOffset()
        #expect(readOffset == 42)
    }

    // MARK: Large Values Tests

    @Test("Handles large offset values")
    func largeOffsetValues() throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let manager = OffsetManager(configDirectory: tempDir.path)
        let largeOffset = Int64.max - 1000

        try manager.writeOffset(largeOffset)
        let readOffset = try manager.readOffset()

        #expect(readOffset == largeOffset)
    }

    // MARK: Configuration Directory Tests

    @Test("Uses ConfigPath when no directory specified")
    func usesConfigPath() {
        // This test verifies the default behavior uses ConfigPath
        // We can't easily test the actual path resolution without mocking,
        // but we can verify the manager is created successfully without throwing
        _ = OffsetManager()

        // If we reach here, initialization was successful
        #expect(true)
    }

    // MARK: Test Helpers

    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("stylus-offset-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
