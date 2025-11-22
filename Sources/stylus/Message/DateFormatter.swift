import Foundation

// MARK: - DateFormatterCache

actor DateFormatterCache {
    // MARK: Properties

    private var formatters: [String: DateFormatter] = [:]

    // MARK: Functions

    func getFormatter(for format: String) -> DateFormatter {
        if let existing = formatters[format] {
            return existing
        }

        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
}

// MARK: - StylusDateFormatter

struct StylusDateFormatter {
    // MARK: Static Properties

    private static let cache = DateFormatterCache()

    // MARK: Functions

    func formatDate(_ format: String, date: Date) async -> String {
        let formatter = await Self.cache.getFormatter(for: format)
        return formatter.string(from: date)
    }
}

// Convenience function for backward compatibility
func formatDate(_ format: String, date: Date) async -> String {
    await StylusDateFormatter().formatDate(format, date: date)
}
