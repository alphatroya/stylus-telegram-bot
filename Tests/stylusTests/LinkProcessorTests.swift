import Foundation
@testable import stylus
import Testing

#if canImport(LinkPresentation)
    import LinkPresentation
#endif

// MARK: - LinkProcessorTests

@Suite("LinkProcessorTests")
struct LinkProcessorTests {
    // MARK: URL Extraction Tests

    @Test("Extract single HTTP URL")
    func extractSingleHTTPURL() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Check this out http://example.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "http://example.com")
    }

    @Test("Extract single HTTPS URL")
    func extractSingleHTTPSURL() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Check this out https://example.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://example.com")
    }

    @Test("Extract multiple URLs")
    func extractMultipleURLs() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Visit https://google.com and http://apple.com for info"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 2)
        #expect(urls.contains("https://google.com"))
        #expect(urls.contains("http://apple.com"))
    }

    @Test("Extract URL with path and query")
    func extractURLWithPathAndQuery() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Go to https://example.com/path/to/page?param=value&other=123"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://example.com/path/to/page?param=value&other=123")
    }

    @Test("No URLs in text")
    func noURLsInText() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "This is just plain text without any links"
        let urls = processor.extractURLs(from: text)

        #expect(urls.isEmpty)
    }

    @Test("Extract URL at end of text")
    func extractURLAtEndOfText() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Hello https://google.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://google.com")
    }

    @Test("Extract URL with trailing punctuation")
    func extractURLWithTrailingPunctuation() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Visit https://example.com. It's great!"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://example.com")
    }

    @Test("Extract duplicate URLs")
    func extractDuplicateURLs() {
        #if canImport(LinkPresentation)
            let processor = LinkProcessor(metadataProvider: MockMetadataProvider())
        #else
            let processor = LinkProcessor()
        #endif
        let text = "Check https://example.com and https://example.com again"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 2)
        #expect(urls[0] == "https://example.com")
        #expect(urls[1] == "https://example.com")
    }

    // MARK: Link Processing Tests

    #if canImport(LinkPresentation)
        @Test("Process text with single URL - mock successful fetch")
        func processTextWithSingleURL() async {
            let mockProvider = MockMetadataProvider()
            await mockProvider.setMockTitle("Google", for: "https://google.com")

            let processor = LinkProcessor(metadataProvider: mockProvider)
            let text = "Hello https://google.com"
            let result = await processor.processLinks(in: text)

            #expect(result == "Hello <a href=\"https://google.com\">Google</a>")
        }

        @Test("Process text with HTML special characters in title")
        func processTextWithHTMLSpecialCharsInTitle() async {
            let mockProvider = MockMetadataProvider()
            await mockProvider.setMockTitle("Cats & Dogs <3", for: "https://example.com")

            let processor = LinkProcessor(metadataProvider: mockProvider)
            let text = "Visit https://example.com"
            let result = await processor.processLinks(in: text)

            #expect(result == "Visit <a href=\"https://example.com\">Cats &amp; Dogs &lt;3</a>")
        }

        @Test("Process text with URL but failed title fetch")
        func processTextWithURLButFailedTitleFetch() async {
            let mockProvider = MockMetadataProvider()
            await mockProvider.setShouldThrowError(true)

            let processor = LinkProcessor(metadataProvider: mockProvider)
            let text = "Hello https://google.com"
            let result = await processor.processLinks(in: text)

            // Should fall back to URL as title
            #expect(result == "Hello <a href=\"https://google.com\">https://google.com</a>")
        }

        @Test("Process text with multiple URLs")
        func processTextWithMultipleURLs() async {
            let mockProvider = MockMetadataProvider()
            await mockProvider.setMockTitle("Google", for: "https://google.com")
            await mockProvider.setMockTitle("Apple", for: "https://apple.com")

            let processor = LinkProcessor(metadataProvider: mockProvider)
            let text = "Visit https://google.com and https://apple.com"
            let result = await processor.processLinks(in: text)

            #expect(result.contains("<a href=\"https://google.com\">Google</a>"))
            #expect(result.contains("<a href=\"https://apple.com\">Apple</a>"))
        }

        @Test("Process text with duplicate URLs")
        func processTextWithDuplicateURLs() async {
            let mockProvider = MockMetadataProvider()
            await mockProvider.setMockTitle("Example", for: "https://example.com")

            let processor = LinkProcessor(metadataProvider: mockProvider)
            let text = "Check https://example.com and https://example.com again"
            let result = await processor.processLinks(in: text)

            // Both occurrences should be replaced
            let expectedLink = "<a href=\"https://example.com\">Example</a>"
            #expect(result == "Check \(expectedLink) and \(expectedLink) again")
        }
    #else
        @Test("Process text with no URLs on non-macOS")
        func processTextWithNoURLs() async {
            let processor = LinkProcessor()
            let text = "Hello world"
            let result = await processor.processLinks(in: text)

            #expect(result == "Hello world")
        }

        @Test("Process text with URL falls back to URL on non-macOS")
        func processTextWithURLFallback() async {
            let processor = LinkProcessor()
            let text = "Hello https://google.com"
            let result = await processor.processLinks(in: text)

            // Should fall back to URL as title on non-macOS
            #expect(result == "Hello <a href=\"https://google.com\">https://google.com</a>")
        }
    #endif
}

#if canImport(LinkPresentation)

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

        func startFetchingMetadata(for url: URL) async throws -> LPLinkMetadata {
            if shouldThrowError {
                throw URLError(.badServerResponse)
            }

            let metadata = LPLinkMetadata()
            metadata.url = url

            if let title = mockTitles[url.absoluteString] {
                metadata.title = title
            } else {
                metadata.title = "Mock Page"
            }

            return metadata
        }
    }
#endif
