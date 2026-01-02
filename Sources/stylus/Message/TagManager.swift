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

/// Extract user name from Message.From with priority: username → first_name + last_name → first_name
func extractUserName(from sender: Message.From) -> String? {
    // Priority 1: username
    if let username = sender.name, !username.isEmpty {
        return username
    }

    // Priority 2: first_name + last_name
    if let firstName = sender.firstName?.trimmingCharacters(in: .whitespaces), !firstName.isEmpty,
       let lastName = sender.lastName?.trimmingCharacters(in: .whitespaces), !lastName.isEmpty
    {
        return "\(firstName) \(lastName)"
    }

    // Priority 3: first_name only
    if let firstName = sender.firstName?.trimmingCharacters(in: .whitespaces), !firstName.isEmpty {
        return firstName
    }

    // No name information available
    return nil
}

/// Create user tag from name: "John James" -> "[[John James]]"
func createUserTag(from name: String) -> String {
    "[[\(name)]]"
}

/// Add user tag before existing tags (e.g., before #stylus-inbox)
func addUserTag(to text: String, userName: String) -> String {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return text }

    let lines = text.components(separatedBy: .newlines)
    guard let firstLine = lines.first else { return text }

    let userTag = createUserTag(from: userName)
    let firstLineWithUserTag = firstLine + " \(userTag)"
    let remainingLines = lines.dropFirst().joined(separator: "\n")

    return remainingLines.isEmpty ? firstLineWithUserTag : firstLineWithUserTag + "\n" + remainingLines
}
