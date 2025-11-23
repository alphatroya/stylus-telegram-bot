import Foundation

// MARK: - DateFormatterCache

actor DateFormatterCache {
    // MARK: Properties

    private var formatters: [String: DateFormatter] = [:]

    // MARK: Functions

    func formatDate(_ format: String, date: Date) -> String {
        let formatter: DateFormatter
        if let existing = formatters[format] {
            formatter = existing
        } else {
            formatter = DateFormatter()
            formatter.dateFormat = format
            formatters[format] = formatter
        }
        return formatter.string(from: date)
    }
}

// MARK: - StylusDateFormatter

struct StylusDateFormatter {
    // MARK: Static Properties

    private static let cache = DateFormatterCache()

    // MARK: Functions

    func formatDate(_ format: String, date: Date) async -> String {
        await Self.cache.formatDate(format, date: date)
    }
}
