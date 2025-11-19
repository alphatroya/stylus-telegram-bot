import Foundation

// MARK: - Tag Management

func addStylusInboxTag(to text: String) -> String {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return text }

    let lines = text.components(separatedBy: .newlines)
    guard let firstLine = lines.first else { return text }

    let firstLineWithTag = firstLine + " #stylus-inbox"
    let remainingLines = lines.dropFirst().joined(separator: "\n")

    return remainingLines.isEmpty ? firstLineWithTag : firstLineWithTag + "\n" + remainingLines
}
