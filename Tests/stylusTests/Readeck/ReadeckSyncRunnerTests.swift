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

    // MARK: Sorting

    @Test
    func `Multiple entries on same day are sorted chronologically`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        // Entries arrive unsorted: 18:55, 09:05, 14:30
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T18:55:00Z", type: "update"),
            BookmarkSyncEntry(id: "b2", time: "2025-06-15T09:05:00Z", type: "update"),
            BookmarkSyncEntry(id: "b3", time: "2025-06-15T14:30:00Z", type: "update"),
        ]
        mockClient.bookmarkDetails = [
            "b1": BookmarkDetail(
                id: "b1",
                title: "Evening Article",
                url: "https://example.com/evening",
                created: "2025-06-15T18:55:00Z",
                labels: [],
                isArchived: false,
            ),
            "b2": BookmarkDetail(
                id: "b2",
                title: "Morning Article",
                url: "https://example.com/morning",
                created: "2025-06-15T09:05:00Z",
                labels: [],
                isArchived: false,
            ),
            "b3": BookmarkDetail(
                id: "b3",
                title: "Afternoon Article",
                url: "https://example.com/afternoon",
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

        // Verify all bookmarks were fetched
        #expect(mockClient.fetchBookmarkCallCount == 3)

        // Verify the written content is sorted by time
        // Since all entries go to the same file, mockFileWorker should have the sorted content
        // For a new file, writeStringToFile is used
        #expect(mockFileWorker.writeStringToFileCallCount == 1)
        let journalContent = mockFileWorker.fileSystem.values.first(where: { $0.contains("Morning Article") })
        #expect(journalContent != nil)

        // Verify order: Morning (09:05) before Afternoon (14:30) before Evening (18:55)
        if let content = journalContent {
            let morningRange = try #require(content.range(of: "Morning Article"))
            let afternoonRange = try #require(content.range(of: "Afternoon Article"))
            let eveningRange = try #require(content.range(of: "Evening Article"))
            #expect(morningRange.lowerBound < afternoonRange.lowerBound)
            #expect(afternoonRange.lowerBound < eveningRange.lowerBound)
        }
    }

    @Test
    func `Multiple days are sorted independently`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T18:00:00Z", type: "update"),
            BookmarkSyncEntry(id: "b2", time: "2025-06-15T09:00:00Z", type: "update"),
            BookmarkSyncEntry(id: "b3", time: "2025-06-16T15:00:00Z", type: "update"),
            BookmarkSyncEntry(id: "b4", time: "2025-06-16T08:00:00Z", type: "update"),
        ]
        mockClient.bookmarkDetails = [
            "b1": BookmarkDetail(
                id: "b1",
                title: "Day1 Evening",
                url: "https://example.com/d1e",
                created: "2025-06-15T18:00:00Z",
                labels: [],
                isArchived: false,
            ),
            "b2": BookmarkDetail(
                id: "b2",
                title: "Day1 Morning",
                url: "https://example.com/d1m",
                created: "2025-06-15T09:00:00Z",
                labels: [],
                isArchived: false,
            ),
            "b3": BookmarkDetail(
                id: "b3",
                title: "Day2 Afternoon",
                url: "https://example.com/d2a",
                created: "2025-06-16T15:00:00Z",
                labels: [],
                isArchived: false,
            ),
            "b4": BookmarkDetail(
                id: "b4",
                title: "Day2 Morning",
                url: "https://example.com/d2m",
                created: "2025-06-16T08:00:00Z",
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

        #expect(mockClient.fetchBookmarkCallCount == 4)

        // Two separate files should be written
        #expect(mockFileWorker.writeStringToFileCallCount == 2)

        // Find each day's content
        let day1Content = mockFileWorker.fileSystem.values.first(where: { $0.contains("Day1") })
        let day2Content = mockFileWorker.fileSystem.values.first(where: { $0.contains("Day2") })
        #expect(day1Content != nil)
        #expect(day2Content != nil)

        // Verify sorting within each day
        if let content = day1Content {
            let morningRange = try #require(content.range(of: "Day1 Morning"))
            let eveningRange = try #require(content.range(of: "Day1 Evening"))
            #expect(morningRange.lowerBound < eveningRange.lowerBound)
        }
        if let content = day2Content {
            let morningRange = try #require(content.range(of: "Day2 Morning"))
            let afternoonRange = try #require(content.range(of: "Day2 Afternoon"))
            #expect(morningRange.lowerBound < afternoonRange.lowerBound)
        }
    }

    @Test
    func `Single entry produces correct output`() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let mockClient = MockReadeckClient()
        mockClient.syncEntries = [
            BookmarkSyncEntry(id: "b1", time: "2025-06-15T14:30:00Z", type: "update"),
        ]
        mockClient.bookmarkDetails = [
            "b1": BookmarkDetail(
                id: "b1",
                title: "Solo Article",
                url: "https://example.com/solo",
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

        #expect(mockClient.fetchBookmarkCallCount == 1)
        #expect(mockFileWorker.writeStringToFileCallCount == 1)

        let content = mockFileWorker.fileSystem.values.first(where: { $0.contains("Solo Article") })
        #expect(content != nil)
        #expect(content?.contains("Solo Article") == true)
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
