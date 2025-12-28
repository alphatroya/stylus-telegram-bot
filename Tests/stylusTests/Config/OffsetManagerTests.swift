import Foundation
import Testing
@testable import stylus

// MARK: - OffsetManagerTests

@Suite("OffsetManager Tests")
struct OffsetManagerTests {
    @Test("Read offset returns nil when file doesn't exist")
    func testReadOffsetFileDoesNotExist() {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        let offset = offsetManager.readOffset()

        #expect(offset == nil)
    }

    @Test("Read offset returns value from file")
    func testReadOffsetReturnsValue() throws {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        // Simulate offset file exists
        let offsetPath = getOffsetPath(fileWorker: fileWorker)
        fileWorker.fileSystem[offsetPath] = "12345\n"

        let offset = offsetManager.readOffset()

        #expect(offset == 12345)
    }

    @Test("Read offset handles invalid content gracefully")
    func testReadOffsetInvalidContent() {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        // Simulate offset file with invalid content
        let offsetPath = getOffsetPath(fileWorker: fileWorker)
        fileWorker.fileSystem[offsetPath] = "invalid"

        let offset = offsetManager.readOffset()

        #expect(offset == nil)
    }

    @Test("Read offset trims whitespace")
    func testReadOffsetTrimsWhitespace() {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        // Simulate offset file with whitespace
        let offsetPath = getOffsetPath(fileWorker: fileWorker)
        fileWorker.fileSystem[offsetPath] = "  67890  \n"

        let offset = offsetManager.readOffset()

        #expect(offset == 67890)
    }

    @Test("Write offset saves to file")
    func testWriteOffset() throws {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        try offsetManager.writeOffset(99999)

        let offsetPath = getOffsetPath(fileWorker: fileWorker)
        let content = fileWorker.fileSystem[offsetPath]
        #expect(content == "99999\n")
    }

    @Test("Write offset overwrites existing value")
    func testWriteOffsetOverwrites() throws {
        let fileWorker = MockFileWorker()
        let offsetManager = OffsetManager(fileWorker: fileWorker)

        // Write initial offset
        try offsetManager.writeOffset(111)

        // Write new offset
        try offsetManager.writeOffset(222)

        let offsetPath = getOffsetPath(fileWorker: fileWorker)
        let content = fileWorker.fileSystem[offsetPath]
        #expect(content == "222\n")
        #expect(fileWorker.writeStringToFileCallCount == 2)
    }
}
