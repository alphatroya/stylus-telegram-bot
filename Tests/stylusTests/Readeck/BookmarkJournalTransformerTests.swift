import Foundation
@testable import stylus
import Testing

@Suite("BookmarkJournalTransformer Tests")
struct BookmarkJournalTransformerTests {
    // MARK: Properties

    private let transformer = BookmarkJournalTransformer()

    // MARK: Functions

    // MARK: Tests

    @Test
    func `Bookmark with title and labels produces correct entry`() {
        let created = "2025-06-15T14:30:00Z"
        let bookmark = BookmarkDetail(
            id: "1",
            title: "Swift Concurrency Guide",
            url: "https://example.com/swift",
            created: created,
            labels: ["programming", "swift"],
            isArchived: false,
        )

        let (fileName, entryLine) = transformer.transform(bookmark)

        #expect(fileName == localJournalDate(from: created))
        #expect(entryLine ==
            "- **\(localTime(from: created))** [Swift Concurrency Guide](https://example.com/swift) #from-readeck #programming #swift #stylus-inbox\n")
    }

    @Test
    func `from-readeck tag is always present`() {
        let bookmark = BookmarkDetail(
            id: "2",
            title: "Test",
            url: "https://example.com",
            created: "2025-01-01T00:00:00Z",
            labels: [],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.contains("#from-readeck"))
    }

    @Test
    func `Empty labels produces only source and inbox tags`() {
        let created = "2025-03-20T09:15:00Z"
        let bookmark = BookmarkDetail(
            id: "3",
            title: "No Labels Article",
            url: "https://example.com/article",
            created: created,
            labels: [],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine ==
            "- **\(localTime(from: created))** [No Labels Article](https://example.com/article) #from-readeck #stylus-inbox\n")
    }

    @Test
    func `Empty title uses URL as link text`() {
        let bookmark = BookmarkDetail(
            id: "4",
            title: "",
            url: "https://example.com/no-title",
            created: "2025-02-10T18:45:00Z",
            labels: [],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.contains("[https://example.com/no-title](https://example.com/no-title)"))
    }

    @Test
    func `Multiple labels become separate tags`() {
        let bookmark = BookmarkDetail(
            id: "5",
            title: "AI Research",
            url: "https://example.com/ai",
            created: "2025-04-01T12:00:00Z",
            labels: ["tech", "ai", "research"],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.contains("#tech #ai #research"))
    }

    @Test
    func `Journal file name uses local timezone`() {
        let bookmark = BookmarkDetail(
            id: "6",
            title: "Dated Entry",
            url: "https://example.com",
            created: "2025-12-25T23:59:00Z",
            labels: [],
            isArchived: false,
        )

        let (fileName, _) = transformer.transform(bookmark)
        #expect(fileName == localJournalDate(from: "2025-12-25T23:59:00Z"))
    }

    @Test
    func `Time string uses local timezone`() {
        let created = "2025-01-01T08:05:00Z"
        let bookmark = BookmarkDetail(
            id: "7",
            title: "Time Test",
            url: "https://example.com",
            created: created,
            labels: [],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.contains("**\(localTime(from: created))**"))
    }

    @Test
    func `stylus-inbox tag is always appended last`() {
        let bookmark = BookmarkDetail(
            id: "8",
            title: "Inbox Test",
            url: "https://example.com",
            created: "2025-01-01T00:00:00Z",
            labels: ["tag1"],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.hasSuffix("#stylus-inbox\n"))
    }

    @Test
    func `Labels with spaces are converted to hyphens and lowercased`() {
        let bookmark = BookmarkDetail(
            id: "9",
            title: "Spaces",
            url: "https://example.com",
            created: "2025-01-01T00:00:00Z",
            labels: ["Machine Learning", "Web Dev"],
            isArchived: false,
        )

        let (_, entryLine) = transformer.transform(bookmark)
        #expect(entryLine.contains("#machine-learning"))
        #expect(entryLine.contains("#web-dev"))
    }

    // MARK: Helpers

    /// Formats a UTC ISO 8601 string to local time string (HH:mm)
    private func localTime(from utcString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        guard let date = formatter.date(from: utcString) else { return "00:00" }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: date)
    }

    /// Formats a UTC ISO 8601 string to local journal date (yyyy_MM_dd.md)
    private func localJournalDate(from utcString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        guard let date = formatter.date(from: utcString) else { return "1970_01_01.md" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy_MM_dd"
        return "\(dateFormatter.string(from: date)).md"
    }
}
