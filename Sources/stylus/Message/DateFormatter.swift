import Foundation

// MARK: - StylusDateFormatter

struct StylusDateFormatter {
    func formatDate(_ format: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

// Convenience function for backward compatibility
func formatDate(_ format: String, date: Date) -> String {
    StylusDateFormatter().formatDate(format, date: date)
}
