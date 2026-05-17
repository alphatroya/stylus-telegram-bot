import Foundation

// MARK: - BookmarkDetail

/// DTO for the Readeck `GET /bookmarks/{id}` response.
///
/// Contains the full bookmark metadata needed to generate a journal entry.
/// All fields except `id`, `url`, and `created` are optional to handle
/// variations in the Readeck API response.
struct BookmarkDetail: Codable {
    // MARK: Nested Types

    // MARK: Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case created
        case labels
        case isArchived
    }

    // MARK: Properties

    /// Unique bookmark identifier
    let id: String
    /// Bookmark title (may be empty or missing)
    let title: String
    /// Bookmark URL
    let url: String
    /// ISO 8601 creation timestamp
    let created: String
    /// Readeck labels/tags associated with the bookmark
    let labels: [String]
    /// Whether the bookmark has been archived
    let isArchived: Bool?

    // MARK: Lifecycle

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try container.decode(String.self, forKey: .url)
        created = try container.decode(String.self, forKey: .created)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived)
    }

    // MARK: Init for Tests

    init(
        id: String,
        title: String,
        url: String,
        created: String,
        labels: [String],
        isArchived: Bool? = nil,
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.created = created
        self.labels = labels
        self.isArchived = isArchived
    }
}
