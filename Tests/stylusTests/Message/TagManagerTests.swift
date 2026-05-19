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
    func `add tag`(input: String, expected: String) {
        let result = addStylusInboxTag(to: input)
        #expect(result == expected)
    }

    @Test(arguments: [
        ("John", "[[John]]"),
        ("John Smith", "[[John Smith]]"),
        ("jane_doe", "[[jane_doe]]"),
    ])
    func `create user tag test`(input: String, expected: String) {
        let result = createUserTag(from: input)
        #expect(result == expected)
    }

    @Test(arguments: [
        ("Hello world", "Jane Doe", "Hello world [[Jane Doe]]"),
        ("Test message", "john_doe", "Test message [[john_doe]]"),
        ("First line\nSecond line", "Alice", "First line [[Alice]]\nSecond line"),
    ])
    func `add user tag test`(input: String, userName: String, expected: String) {
        let result = addUserTag(to: input, userName: userName)
        #expect(result == expected)
    }

    @Test
    func `extract user name with username`() {
        let from = Message.From(id: 123, name: "johndoe", firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "johndoe")
    }

    @Test
    func `extract user name with full name`() {
        let from = Message.From(id: 123, name: nil, firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "John Doe")
    }

    @Test
    func `extract user name with first name only`() {
        let from = Message.From(id: 123, name: nil, firstName: "John", lastName: nil)
        let result = extractUserName(from: from)
        #expect(result == "John")
    }

    @Test
    func `extract user name with no name`() {
        let from = Message.From(id: 123, name: nil, firstName: nil, lastName: nil)
        let result = extractUserName(from: from)
        #expect(result == nil)
    }

    @Test
    func `extract user name with empty strings`() {
        let from = Message.From(id: 123, name: "", firstName: "", lastName: "")
        let result = extractUserName(from: from)
        #expect(result == nil)
    }

    @Test
    func `extract user name prioritizes username`() {
        let from = Message.From(id: 123, name: "johnny", firstName: "John", lastName: "Doe")
        let result = extractUserName(from: from)
        #expect(result == "johnny")
    }

    @Test
    func `extract user name with first name and empty last name`() {
        let from = Message.From(id: 123, name: nil, firstName: "Alice", lastName: "")
        let result = extractUserName(from: from)
        #expect(result == "Alice")
    }

    @Test
    func `extract user name trims whitespace`() {
        let from = Message.From(id: 123, name: nil, firstName: "  John  ", lastName: "  Doe  ")
        let result = extractUserName(from: from)
        #expect(result == "John Doe")
    }
}
