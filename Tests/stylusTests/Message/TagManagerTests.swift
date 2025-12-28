import Foundation
@testable import stylus
import Testing

// MARK: - TagManagerTests

@Suite("TagManagerTests")
struct TagManagerTests {
    @Test(arguments: [
        ("Hello world", "Hello world #stylus-inbox"),
        ("", ""),
        ("First line\nSecond line\nThird line", "First line #stylus-inbox\nSecond line\nThird line"),
        ("\nSecond line\nThird line", " #stylus-inbox\nSecond line\nThird line"),
        ("   ", "   "),
        ("Only line\n\n", "Only line #stylus-inbox\n\n"),
    ])
    func addTag(input: String, expected: String) {
        let result = addStylusInboxTag(to: input)
        #expect(result == expected)
    }

    @Test(arguments: [
        ("John", "[[John]]"),
        ("John Smith", "[[John Smith]]"),
        ("jane_doe", "[[jane_doe]]"),
    ])
    func createUserTagTest(input: String, expected: String) {
        let result = createUserTag(from: input)
        #expect(result == expected)
    }

    @Test(arguments: [
        ("Hello world", "Jane Doe", "Hello world [[Jane Doe]]"),
        ("Test message", "john_doe", "Test message [[john_doe]]"),
        ("First line\nSecond line", "Alice", "First line [[Alice]]\nSecond line"),
    ])
    func addUserTagTest(input: String, userName: String, expected: String) {
        let result = addUserTag(to: input, userName: userName)
        #expect(result == expected)
    }

    @Test
    func extractUserNameWithUsername() {
        let from = Message.From(id: 123, name: "johndoe", firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "johndoe")
    }

    @Test
    func extractUserNameWithFullName() {
        let from = Message.From(id: 123, name: nil, firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "John Doe")
    }

    @Test
    func extractUserNameWithFirstNameOnly() {
        let from = Message.From(id: 123, name: nil, firstName: "John", lastName: nil)
        let result = extractUserName(from: from)
        #expect(result == "John")
    }

    @Test
    func extractUserNameWithNoName() {
        let from = Message.From(id: 123, name: nil, firstName: nil, lastName: nil)
        let result = extractUserName(from: from)
        #expect(result == nil)
    }

    @Test
    func extractUserNameWithEmptyStrings() {
        let from = Message.From(id: 123, name: "", firstName: "", lastName: "")
        let result = extractUserName(from: from)
        #expect(result == nil)
    }

    @Test
    func extractUserNamePrioritizesUsername() {
        let from = Message.From(id: 123, name: "johnny", firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "johnny")
    }

    @Test
    func extractUserNameWithFirstNameAndEmptyLastName() {
        let from = Message.From(id: 123, name: nil, firstName: "Alice", lastName: "")
        let result = extractUserName(from: from)
        #expect(result == "Alice")
    }

    @Test
    func extractUserNameTrimsWhitespace() {
        let from = Message.From(id: 123, name: nil, firstName: "  John  ", lastName: "  Doe  ")
        let result = extractUserName(from: from)
        #expect(result == "John Doe")
    }
}
