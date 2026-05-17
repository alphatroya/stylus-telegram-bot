import Foundation

// MARK: - BookmarkSyncEntry

/// DTO for entries returned by the Readeck `/bookmarks/sync` endpoint.
///
/// Each entry represents a bookmark that has been created, updated, or deleted
/// since the last sync timestamp.
struct BookmarkSyncEntry: Codable {
    // MARK: Nested Types

    // MARK: Enums

    enum SyncType: String, Decodable {
        case update
        case delete
    }

    // MARK: Properties

    /// Unique bookmark identifier
    let id: String
    /// ISO 8601 timestamp of when this change occurred
    let time: String
    /// Type of change: "update" or "delete"
    let type: String

    // MARK: Computed Properties

    /// Parsed sync type, returns nil for unknown types
    var syncType: SyncType? {
        SyncType(rawValue: type)
    }
}
