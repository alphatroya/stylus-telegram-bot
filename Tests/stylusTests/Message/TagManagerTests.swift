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
}
