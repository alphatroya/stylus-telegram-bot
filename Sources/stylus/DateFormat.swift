import Foundation

func formatDate(_ format: String, date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}
