import Foundation
@testable import stylus
import Testing

// MARK: - DateFormatterTests

@Suite("DateFormatterTests")
struct DateFormatterTests {
    @Test(arguments: [
        ("yyyy-MM-dd", 1_609_459_200.0, "2021-01-01"),
        ("dd/MM/yy", 1_609_459_200.0, "01/01/21"),
        ("dd MMMM yyyy", 1_609_459_200.0, "01 January 2021"),
        ("dd MMM yyyy", 1_609_459_200.0, "01 Jan 2021"),
        ("yyyy/MM/dd", 1_609_459_200.0, "2021/01/01"),
        ("", 1_609_459_200.0, ""),
        ("yyyy-MM-dd", 1_640_995_200.0, "2022-01-01"),
        ("yyyy_MM_dd", 1_609_459_200.0, "2021_01_01"),
    ])
    func `formats date with pattern`(format: String, timestamp: TimeInterval, expected: String) async {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = StylusDateFormatter()
        let result = await formatter.formatDate(format, date: date)
        #expect(result == expected)
    }
}
