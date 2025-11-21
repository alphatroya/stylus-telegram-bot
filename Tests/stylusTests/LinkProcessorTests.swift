import Foundation
@testable import stylus
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - LinkProcessorTests

@Suite("LinkProcessorTests")
struct LinkProcessorTests {
    // MARK: URL Extraction Tests

    @Test("Extract single HTTP URL")
    func extractSingleHTTPURL() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Check this out http://example.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "http://example.com")
    }

    @Test("Extract single HTTPS URL")
    func extractSingleHTTPSURL() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Check this out https://example.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://example.com")
    }

    @Test("Extract multiple URLs")
    func extractMultipleURLs() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Visit https://google.com and http://apple.com for info"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 2)
        #expect(urls.contains("https://google.com"))
        #expect(urls.contains("http://apple.com"))
    }

    @Test("Extract URL with path and query")
    func extractURLWithPathAndQuery() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Go to https://example.com/path/to/page?param=value&other=123"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://example.com/path/to/page?param=value&other=123")
    }

    @Test("No URLs in text")
    func noURLsInText() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "This is just plain text without any links"
        let urls = processor.extractURLs(from: text)

        #expect(urls.isEmpty)
    }

    @Test("Extract URL at end of text")
    func extractURLAtEndOfText() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Hello https://google.com"
        let urls = processor.extractURLs(from: text)

        #expect(urls.count == 1)
        #expect(urls.first == "https://google.com")
    }

    // MARK: Title Extraction Tests

    @Test("Extract title from simple HTML")
    func extractTitleFromSimpleHTML() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let html = "<html><head><title>Example Page</title></head><body>Content</body></html>"
        let title = processor.extractTitle(from: html)

        #expect(title == "Example Page")
    }

    @Test("Extract title with HTML entities")
    func extractTitleWithHTMLEntities() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let html = "<html><head><title>Cats &amp; Dogs</title></head></html>"
        let title = processor.extractTitle(from: html)

        #expect(title == "Cats & Dogs")
    }

    @Test("Extract title with numeric HTML entities")
    func extractTitleWithNumericHTMLEntities() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let html = "<html><head><title>Test &#65; &#66;</title></head></html>"
        let title = processor.extractTitle(from: html)

        #expect(title == "Test A B")
    }

    @Test("Extract title with whitespace")
    func extractTitleWithWhitespace() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let html = "<html><head><title>  My Page  </title></head></html>"
        let title = processor.extractTitle(from: html)

        #expect(title == "My Page")
    }

    @Test("No title in HTML")
    func noTitleInHTML() {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let html = "<html><head></head><body>Content</body></html>"
        let title = processor.extractTitle(from: html)

        #expect(title == nil)
    }

    // MARK: Link Processing Tests

    @Test("Process text with single URL - mock successful fetch")
    func processTextWithSingleURL() async throws {
        let mockSession = MockURLSession()
        try await mockSession.setMockResponse(
            #require("<html><head><title>Google</title></head></html>".data(using: .utf8)),
            #require(HTTPURLResponse(
                url: #require(URL(string: "https://google.com")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil,
            )),
        )

        let processor = LinkProcessor(urlSession: mockSession)
        let text = "Hello https://google.com"
        let result = await processor.processLinks(in: text)

        #expect(result == "Hello <a href=\"https://google.com\">Google</a>")
    }

    @Test("Process text with HTML special characters in title")
    func processTextWithHTMLSpecialCharsInTitle() async throws {
        let mockSession = MockURLSession()
        try await mockSession.setMockResponse(
            #require("<html><head><title>Cats & Dogs <3</title></head></html>".data(using: .utf8)),
            #require(HTTPURLResponse(
                url: #require(URL(string: "https://example.com")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil,
            )),
        )

        let processor = LinkProcessor(urlSession: mockSession)
        let text = "Visit https://example.com"
        let result = await processor.processLinks(in: text)

        #expect(result == "Visit <a href=\"https://example.com\">Cats &amp; Dogs &lt;3</a>")
    }

    @Test("Process text with no URLs")
    func processTextWithNoURLs() async {
        let processor = LinkProcessor(urlSession: MockURLSession())
        let text = "Hello world"
        let result = await processor.processLinks(in: text)

        #expect(result == "Hello world")
    }

    @Test("Process text with URL but failed title fetch")
    func processTextWithURLButFailedTitleFetch() async {
        let mockSession = MockURLSession()
        await mockSession.setShouldThrowError(true)

        let processor = LinkProcessor(urlSession: mockSession)
        let text = "Hello https://google.com"
        let result = await processor.processLinks(in: text)

        // Should fall back to URL as title
        #expect(result == "Hello <a href=\"https://google.com\">https://google.com</a>")
    }

    @Test("Process text with multiple URLs")
    func processTextWithMultipleURLs() async throws {
        let mockSession = MockURLSession()
        try await mockSession.setMockResponses([
            "https://google.com": (
                #require("<html><head><title>Google</title></head></html>".data(using: .utf8)),
                #require(HTTPURLResponse(
                    url: #require(URL(string: "https://google.com")),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil,
                )),
            ),
            "https://apple.com": (
                #require("<html><head><title>Apple</title></head></html>".data(using: .utf8)),
                #require(HTTPURLResponse(
                    url: #require(URL(string: "https://apple.com")),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil,
                )),
            ),
        ])

        let processor = LinkProcessor(urlSession: mockSession)
        let text = "Visit https://google.com and https://apple.com"
        let result = await processor.processLinks(in: text)

        #expect(result.contains("<a href=\"https://google.com\">Google</a>"))
        #expect(result.contains("<a href=\"https://apple.com\">Apple</a>"))
    }
}

// MARK: - MockURLSession

actor MockURLSession: URLSessionProtocol {
    // MARK: Properties

    var mockResponse: (Data, URLResponse)?
    var mockResponses: [String: (Data, URLResponse)] = [:]
    var shouldThrowError = false

    // MARK: Functions

    func setMockResponse(_ data: Data, _ response: URLResponse) {
        mockResponse = (data, response)
    }

    func setMockResponses(_ responses: [String: (Data, URLResponse)]) {
        mockResponses = responses
    }

    func setShouldThrowError(_ value: Bool) {
        shouldThrowError = value
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldThrowError {
            throw URLError(.badServerResponse)
        }

        // Check if we have a URL-specific response
        if let urlString = request.url?.absoluteString,
           let response = mockResponses[urlString]
        {
            return response
        }

        // Fall back to default mock response
        guard let response = mockResponse else {
            let defaultData = "<html><head><title>Mock Page</title></head></html>".data(using: .utf8)!
            let defaultResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil,
            )!
            return (defaultData, defaultResponse)
        }

        return response
    }
}
