import Foundation

// MARK: - StylusDateFormatter

struct StylusDateFormatter {
    // MARK: Static Properties

    private static var formatters: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    // MARK: Static Functions

    private static func getFormatter(for format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }

        if let existing = formatters[format] {
            return existing
        }

        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }

    // MARK: Functions

    func formatDate(_ format: String, date: Date) -> String {
        let formatter = Self.getFormatter(for: format)
        return formatter.string(from: date)
    }
}

// Convenience function for backward compatibility
func formatDate(_ format: String, date: Date) -> String {
    StylusDateFormatter().formatDate(format, date: date)
}
