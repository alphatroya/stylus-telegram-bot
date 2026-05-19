import Foundation

// MARK: - BookmarkJournalTransformer

/// Converts Readeck bookmark details into journal entry markdown lines.
///
/// Each bookmark becomes a single markdown line in the format:
/// `- **HH:mm** [Title](url) #from-readeck #label1 #label2 #stylus-inbox\n`
///
/// The journal file date is determined by the bookmark's `created` field.
struct BookmarkJournalTransformer {
    // MARK: Properties

    private let dateFormatter: ISO8601DateFormatter

    // MARK: Lifecycle

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateFormatter = formatter
    }

    // MARK: Functions

    /// Transforms a bookmark detail into a journal entry line.
    ///
    /// - Parameter bookmark: The bookmark to transform.
    /// - Returns: A tuple of (journalFileName, entryLine), where journalFileName is `yyyy_MM_dd.md`
    ///   and entryLine is the formatted markdown line.
    func transform(_ bookmark: BookmarkDetail) -> (journalFileName: String, entryLine: String) {
        let date = parseDate(from: bookmark.created)
        let timeString = formatTime(from: date)
        let journalFileName = formatJournalDate(from: date)
        let linkText = bookmark.title.isEmpty ? bookmark.url : bookmark.title
        let tags = buildTags(from: bookmark.labels)

        let entryLine = "- **\(timeString)** [\(linkText)](\(bookmark.url)) \(tags)\n"

        return (journalFileName: journalFileName, entryLine: entryLine)
    }

    // MARK: Private Functions

    private func parseDate(from iso8601String: String) -> Date {
        // Try with fractional seconds first, then without
        if let date = dateFormatter.date(from: iso8601String) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        if let date = fallbackFormatter.date(from: iso8601String) {
            return date
        }

        // Last resort: try standard DateFormatter
        let standardFormatter = DateFormatter()
        standardFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = standardFormatter.date(from: iso8601String) {
            return date
        }

        // Absolute fallback: use current date
        print("Warning: Could not parse date '\(iso8601String)', using current date")
        return Date()
    }

    private func formatTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatJournalDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        let dateString = formatter.string(from: date)
        return "\(dateString).md"
    }

    private func buildTags(from labels: [String]) -> String {
        var tags = ["#from-readeck"]
        for label in labels {
            let sanitized = label
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
            if !sanitized.isEmpty {
                tags.append("#\(sanitized)")
            }
        }
        tags.append("#stylus-inbox")
        return tags.joined(separator: " ")
    }
}
