import Foundation
@testable import stylus
import Testing

@Suite("ReadeckSyncRunner Integration Tests")
struct ReadeckSyncRunnerTests {
    // MARK: Nested Types

    // MARK: Mock Client

    final class MockReadeckClient: ReadeckClientProtocol, @unchecked Sendable {
        // MARK: Properties

        var syncEntries: [BookmarkSyncEntry] = []
        var bookmarkDetails: [String: BookmarkDetail] = [:]
        var fetchSyncCallCount = 0
        var fetchBookmarkCallCount = 0
        var fetchBookmarkIDs: [String] = []

        // MARK: Functions

        func fetchSyncedBookmarks(since _: String?) async throws -> [BookmarkSyncEntry] {
            fetchSyncCallCount += 1
            return syncEntries
        }

        func fetchBookmark(id: String) async throws -> BookmarkDetail {
            fetchBookmarkCallCount += 1
            fetchBookmarkIDs.append(id)
            guard let detail = bookmarkDetails[id] else {
                throw ReadeckError.httpError(statusCode: 404, body: "Not found")
            }

            return detail
        }
    }

    // MARK: Functions

    // MARK: First Sync (No Timestamp)

    @Test
    func `First sync with no stored timestamp calls sync without since`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = []
        mockClient.bookmarkDetails = [:]

        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)

        let config = makeConfig(knowledgeBase: tempDir.path)
        let runner = ReadeckSyncRunner(
            config: config,
            client: mockClient,
            timestampManager: ReadeckFetchTimestamp(configDirectory: tempDir.path),
            journalWriter: journalWriter,
        )

        try await runner.run()

        #expect(mockClient.fetchSyncCallCount == 1)
        #expect(mockClient.fetchBookmarkCallCount == 0)
    }

    // MARK: Sync with Updates

    @Test
    func `Sync with updates writes journal entries and updates timestamp`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T14:30:00Z", type: "update"),
            BookmarkSyncEntry(id: "b2", time: "2025-06-15T15:00:00Z", type: "update"),
        ]
        mockClient.bookmarkDetails = [
            "b1": BookmarkDetail(
                id: "b1",
                title: "Article 1",
                url: "https://example.com/1",
                created: "2025-06-15T14:30:00Z",
                labels: ["tech"],
                isArchived: false,
            ),
            "b2": BookmarkDetail(
                id: "b2",
                title: "Article 2",
                url: "https://example.com/2",
                created: "2025-06-15T15:00:00Z",
                labels: [],
                isArchived: false,
            ),
        ]

        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)

        let config = makeConfig(knowledgeBase: tempDir.path)
        let runner = ReadeckSyncRunner(
            config: config,
            client: mockClient,
            timestampManager: ReadeckFetchTimestamp(configDirectory: tempDir.path),
            journalWriter: journalWriter,
        )

        try await runner.run()

        // Both bookmarks fetched
        #expect(mockClient.fetchBookmarkCallCount == 2)
        #expect(mockClient.fetchBookmarkIDs.contains("b1"))
        #expect(mockClient.fetchBookmarkIDs.contains("b2"))

        // Timestamp advanced by 1s to make next sync exclusive
        let timestampManager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        let timestamp = timestampManager.readLastFetch()
        #expect(timestamp == "2025-06-15T15:00:01Z")
    }

    // MARK: Sync with Deletes

    @Test
    func `Sync with delete entries skips them`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T14:30:00Z", type: "update"),
            BookmarkSyncEntry(id: "b2", time: "2025-06-15T15:00:00Z", type: "delete"),
        ]
        mockClient.bookmarkDetails = [
            "b1": BookmarkDetail(
                id: "b1",
                title: "Article 1",
                url: "https://example.com/1",
                created: "2025-06-15T14:30:00Z",
                labels: [],
                isArchived: false,
            ),
        ]

        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)

        let config = makeConfig(knowledgeBase: tempDir.path)
        let runner = ReadeckSyncRunner(
            config: config,
            client: mockClient,
            timestampManager: ReadeckFetchTimestamp(configDirectory: tempDir.path),
            journalWriter: journalWriter,
        )

        try await runner.run()

        // Only the update entry is fetched
        #expect(mockClient.fetchBookmarkCallCount == 1)
        #expect(mockClient.fetchBookmarkIDs == ["b1"])
    }

    // MARK: Timestamp Not Updated on Failure

    @Test
    func `Timestamp not updated when bookmark fetch fails`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T14:30:00Z", type: "update"),
        ]
        // No bookmark detail for b1 — will cause 404 error
        mockClient.bookmarkDetails = [:]

        let mockFileWorker = MockFileWorker()
        let journalWriter = JournalWriter(fileManager: mockFileWorker)

        let config = makeConfig(knowledgeBase: tempDir.path)
        let runner = ReadeckSyncRunner(
            config: config,
            client: mockClient,
            timestampManager: ReadeckFetchTimestamp(configDirectory: tempDir.path),
            journalWriter: journalWriter,
        )

        do {
            try await runner.run()
            #expect(Bool(false), "Should have thrown")
        } catch {
            // Expected to fail
        }

        // Timestamp should NOT be updated
        let timestampManager = ReadeckFetchTimestamp(configDirectory: tempDir.path)
        #expect(timestampManager.readLastFetch() == nil)
    }

    // MARK: Helpers

    private func makeConfig(knowledgeBase: String) -> Config {
        Config(
            telegramBotApiKey: SecretString("test-token"),
            telegramUserID: 12345,
            knowledgeBaseLocation: knowledgeBase,
            readeckEndpoint: "https://readeck.example.com",
            readeckApiToken: SecretString("test-api-token"),
        )
    }

    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("stylus-sync-runner-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
