import Foundation

// MARK: - ReadeckSyncRunner

/// Orchestrates the full Readeck bookmark sync flow.
///
/// The sync process:
/// 1. Read last fetch timestamp from persistent storage
/// 2. Call Readeck `/bookmarks/sync` API to get changed bookmarks
/// 3. Fetch full details for updated bookmarks
/// 4. Transform bookmarks into journal entries
/// 5. Write entries to daily journal files
/// 6. Update the last fetch timestamp (only after all bookmarks are successfully processed)
struct ReadeckSyncRunner {
    // MARK: Properties

    private let config: Config
    private let client: any ReadeckClientProtocol
    private let timestampManager: ReadeckFetchTimestamp
    private let transformer: BookmarkJournalTransformer
    private let journalWriter: JournalWriter

    // MARK: Lifecycle

    init(
        config: Config,
        client: (any ReadeckClientProtocol)? = nil,
        timestampManager: ReadeckFetchTimestamp? = nil,
        transformer: BookmarkJournalTransformer? = nil,
        journalWriter: JournalWriter? = nil,
    ) {
        self.config = config
        self.client = client ?? ReadeckClient(
            endpoint: config.readeckEndpoint!,
            apiToken: config.readeckApiToken!.unsafeValue,
        )
        self.timestampManager = timestampManager ?? ReadeckFetchTimestamp()
        self.transformer = transformer ?? BookmarkJournalTransformer()
        self.journalWriter = journalWriter ?? JournalWriter()
    }

    // MARK: Static Functions

    private static func advanceByMicrosecond(_ iso8601String: String) -> String {
        // Add 1 second to make the stored timestamp exclusive — the Readeck `since`
        // parameter is inclusive, so without this the last article would be re-fetched
        // on every sync.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: iso8601String) {
            return formatter.string(from: date.addingTimeInterval(1))
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: iso8601String) {
            return fallback.string(from: date.addingTimeInterval(1))
        }

        return iso8601String
    }

    // MARK: Functions

    /// Runs the full sync flow.
    func run() async throws {
        print("🔄 Starting Readeck sync")

        // 1. Read last fetch timestamp
        let lastFetch = timestampManager.readLastFetch()
        if let lastFetch {
            print("📅 Resuming from timestamp: \(lastFetch)")
        } else {
            print("📅 Starting fresh (no previous timestamp found)")
        }

        // 2. Fetch synced bookmarks
        let syncEntries = try await client.fetchSyncedBookmarks(since: lastFetch)
        print("📥 Found \(syncEntries.count) changed bookmark(s)")

        if syncEntries.isEmpty {
            print("✅ No new bookmarks to process, exiting cleanly")
            return
        }

        // 3. Filter to updates only (skip deletes)
        let updateEntries = syncEntries.filter { $0.syncType == .update }
        let deleteCount = syncEntries.count - updateEntries.count
        if deleteCount > 0 {
            print("🗑  Skipping \(deleteCount) deleted bookmark(s)")
        }

        guard !updateEntries.isEmpty else {
            print("✅ No updated bookmarks to process")
            // Still update timestamp since we've processed all changes
            try updateTimestamp(from: syncEntries)
            return
        }

        // 4. Fetch details and transform to journal entries
        let journalsURL = URL(fileURLWithPath: config.knowledgeBaseLocation)
            .appendingPathComponent("journals")
        try await journalWriter.ensureDirectoryExists(at: journalsURL.path)

        var processedCount = 0

        for entry in updateEntries {
            do {
                let bookmark = try await client.fetchBookmark(id: entry.id)
                let (fileName, entryLine) = transformer.transform(bookmark)
                let filePath = journalsURL.appendingPathComponent(fileName).path

                try await journalWriter.appendToJournalFile(at: filePath, content: entryLine)
                processedCount += 1
                print("✅ Processed bookmark \(processedCount)/\(updateEntries.count): \(bookmark.title)")
            } catch {
                print("❌ Error processing bookmark \(entry.id): \(error.localizedDescription)")
                throw error
            }
        }

        // 5. Update timestamp only after all bookmarks processed successfully
        try updateTimestamp(from: syncEntries)

        print("🎉 Readeck sync complete! Processed \(processedCount) bookmark(s)")
    }

    // MARK: Private Functions

    private func updateTimestamp(from entries: [BookmarkSyncEntry]) throws {
        // Use the latest time from the sync response + 1 microsecond
        // to make the next sync's `since` parameter effectively exclusive
        let latestTime = entries.map(\.time).sorted().last
        guard let latestTime else { return }

        let advancedTime = Self.advanceByMicrosecond(latestTime)
        try timestampManager.writeLastFetch(advancedTime)
        print("💾 Updated last fetch timestamp to: \(advancedTime)")
    }
}
