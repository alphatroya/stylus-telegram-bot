import Foundation
@preconcurrency import LinkPresentation
@testable import stylus
import Testing

// MARK: - LinkProcessorTests

@Suite("LinkProcessorTests")
struct LinkProcessorTests {
    @Test(arguments: [
        ("Check out https://example.com", ["https://example.com"]),
        ("Visit http://test.com and https://another.com", ["http://test.com", "https://another.com"]),
        ("No links here", []),
        ("URL at end: https://final.com", ["https://final.com"]),
        ("URL with path: https://example.com/path/to/page", ["https://example.com/path/to/page"]),
        ("URL with query: https://example.com?param=value", ["https://example.com?param=value"]),
        ("URL with fragment: https://example.com#section", ["https://example.com#section"]),
        ("Visit https://example.com.", ["https://example.com"]),
        ("Check https://example.com, and this", ["https://example.com"]),
        ("Link: https://example.com!", ["https://example.com"]),
        ("See https://example.com?", ["https://example.com"]),
        ("URL https://example.com;", ["https://example.com"]),
        ("End with https://example.com:", ["https://example.com"]),
        ("Parentheses (https://example.com)", ["https://example.com"]),
        ("Multiple punctuation https://example.com...", ["https://example.com"]),
        ("Mixed punctuation https://example.com.,!?", ["https://example.com"]),
        ("Quotes 'https://example.com'", ["https://example.com"]),
        ("Backticks `https://example.com`", ["https://example.com"]),
        ("Angle brackets <https://example.com>", ["https://example.com"]),
        ("Curly braces {https://example.com}", ["https://example.com"]),
    ])
    func extractURLs(input: String, expected: [String]) {
        let processor = LinkProcessor()
        #expect(processor.extractURLs(from: input) == expected)
    }

    @Test("Fetch page title successfully")
    func fetchPageTitleSuccess() async throws {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Test Page Title", for: "https://example.com")
        let processor = LinkProcessor()

        let meta = try await processor.fetchPageTitle(from: "https://example.com", provider: mockProvider)
        let title = try #require(meta).0
        #expect(title == "Test Page Title")
    }

    @Test("Fetch page title with empty title")
    func fetchPageTitleEmpty() async throws {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("", for: "https://example.com")
        let processor = LinkProcessor()

        let meta = try await processor.fetchPageTitle(from: "https://example.com", provider: mockProvider)
        let title = try #require(meta).0
        #expect(title == "")
    }

    @Test("Fetch page title with invalid URL")
    func fetchPageTitleInvalidURL() async {
        let mockProvider = MockMetadataProvider()
        let processor = LinkProcessor()

        let title = try? await processor.fetchPageTitle(from: "", provider: mockProvider)
        #expect(title == nil)
    }

    @Test("Fetch page title with error")
    func fetchPageTitleError() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setShouldThrowError(true)
        let processor = LinkProcessor()

        do {
            _ = try await processor.fetchPageTitle(from: "https://example.com", provider: mockProvider)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(Bool(true), "Expected error was thrown")
        }
    }

    @Test("Process links in text with no URLs")
    func processLinksNoURLs() async {
        let processor = LinkProcessor()
        let input = "This text has no links"

        let result = await processor.processLinks(in: input)
        #expect(result == input)
    }

    @Test("Process links in text with single URL")
    func processLinksSingleURL() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Example Page", for: "https://example.com")
        let processor = LinkProcessor()
        let input = "Visit https://example.com for more info"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Visit [Example Page](https://example.com) for more info")
    }

    @Test("Process links in text with multiple URLs")
    func processLinksMultipleURLs() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Example", for: "https://example.com")
        await mockProvider.setMockTitle("Test Site", for: "https://test.com")
        let processor = LinkProcessor()
        let input = "Check https://example.com and also https://test.com"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Check [Example](https://example.com) and also [Test Site](https://test.com)")
    }

    @Test("Process links with special characters in title")
    func processLinksSpecialCharsInTitle() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Page with & special <chars>", for: "https://example.com")
        let processor = LinkProcessor()
        let input = "Link: https://example.com"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Link: [Page with & special <chars>](https://example.com)")
    }

    @Test("Process links with special characters in URL")
    func processLinksSpecialCharsInURL() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Test Page", for: "https://example.com/path?param=value&other=123")
        let processor = LinkProcessor()
        let input = "URL: https://example.com/path?param=value&other=123"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "URL: [Test Page](https://example.com/path?param=value&other=123)")
    }

    @Test("Process links with missing title fallback to URL")
    func processLinksMissingTitle() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("", for: "https://example.com")
        let processor = LinkProcessor()
        let input = "Link: https://example.com"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Link: https://example.com")
    }

    @Test("Process links with duplicate URLs")
    func processLinksDuplicateURLs() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Example", for: "https://example.com")
        let processor = LinkProcessor()
        let input = "Visit https://example.com and https://example.com again"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Visit [Example](https://example.com) and [Example](https://example.com) again")
    }

    @Test("Process links with overlapping URLs")
    func processLinksOverlappingURLs() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Short", for: "https://short.com")
        await mockProvider.setMockTitle("Long", for: "https://long.com/path")
        let processor = LinkProcessor()
        let input = "Links: https://long.com/path and https://short.com"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Links: [Long](https://long.com/path) and [Short](https://short.com)")
    }

    // MARK: - Tracking Parameter Tests

    @Test(arguments: [
        ("https://example.com?utm_source=google&utm_medium=cpc", "https://example.com"),
        ("https://example.com?utm_campaign=test&param=keep", "https://example.com?param=keep"),
        ("https://example.com?fbclid=123456789", "https://example.com"),
        ("https://example.com?gclid=abc123&keep=value", "https://example.com?keep=value"),
        ("https://example.com?ref_=nb_sb_noss&tag=amazon", "https://example.com"),
        ("https://example.com?pf_rd_p=123&pf_rd_r=456", "https://example.com"),
        ("https://example.com?keep1=value1&utm_source=test&keep2=value2", "https://example.com?keep1=value1&keep2=value2"),
        ("https://example.com", "https://example.com"),
        ("https://example.com?", "https://example.com"),
        ("https://example.com?normal_param=value", "https://example.com?normal_param=value"),
    ])
    func cleanTrackingParameters(input: String, expected: String) {
        let processor = LinkProcessor()
        #expect(processor.cleanTrackingParameters(from: input) == expected)
    }

    @Test("Extract URLs with tracking parameters removed")
    func extractURLsWithTrackingRemoved() {
        let processor = LinkProcessor()
        let input = "Check out https://example.com?utm_source=google&utm_medium=email&keep=this"

        let urls = processor.extractURLs(from: input)
        #expect(urls == ["https://example.com?keep=this"])
    }

    @Test("Process links removes tracking parameters")
    func processLinksRemovesTracking() async {
        let mockProvider = MockMetadataProvider()
        await mockProvider.setMockTitle("Clean Example", for: "https://example.com?keep=this")
        let processor = LinkProcessor()
        let input = "Visit https://example.com?utm_source=google&keep=this for info"

        let result = await processor.processLinks(in: input, metadataProvider: { mockProvider })
        #expect(result == "Visit [Clean Example](https://example.com?keep=this) for info")
    }

    @Test("Clean tracking preserves URL fragments and paths")
    func cleanTrackingPreservesFragmentsAndPaths() {
        let processor = LinkProcessor()
        let input = "https://example.com/path/to/page?utm_source=test&valid=param#section"

        let result = processor.cleanTrackingParameters(from: input)
        #expect(result == "https://example.com/path/to/page?valid=param#section")
    }

    @Test("Clean tracking handles prefix matching")
    func cleanTrackingHandlesPrefixMatching() {
        let processor = LinkProcessor()
        let input = "https://amazon.com?pf_rd_custom=123&pf_rd_another=456&keep=this"

        let result = processor.cleanTrackingParameters(from: input)
        #expect(result == "https://amazon.com?keep=this")
    }

    @Test("Clean tracking with malformed URLs returns original")
    func cleanTrackingMalformedURL() {
        let processor = LinkProcessor()
        let input = "not-a-url"

        let result = processor.cleanTrackingParameters(from: input)
        #expect(result == "not-a-url")
    }
}

// MARK: - MockMetadataProvider

actor MockMetadataProvider: LinkMetadataProviderProtocol {
    // MARK: Properties

    private var mockTitles: [String: String] = [:]
    private var shouldThrowError = false

    // MARK: Functions

    func setMockTitle(_ title: String, for urlString: String) {
        mockTitles[urlString] = title
    }

    func setShouldThrowError(_ value: Bool) {
        shouldThrowError = value
    }

    func fetchMetadata(for url: URL) async throws -> LinkMetadata {
        if shouldThrowError {
            throw URLError(.badServerResponse)
        }

        var metadata = LinkMetadata(url: url)
        if let title = mockTitles[url.absoluteString] {
            metadata.title = title
        } else {
            metadata.title = "Mock Page"
        }

        return metadata
    }
}
