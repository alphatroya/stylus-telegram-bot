import Foundation
@testable import stylus
import Testing

@Suite("ReadeckClient Tests", .serialized)
struct ReadeckClientTests {
    // MARK: Nested Types

    // MARK: Mock URLSession

    /// A mock URLProtocol that captures requests and returns pre-configured responses.
    final class MockURLProtocol: URLProtocol, @unchecked Sendable {
        // MARK: Static Properties

        nonisolated(unsafe) static var mockResponse: (data: Data, statusCode: Int)?
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var capturedAuthorization: String?

        // MARK: Overridden Functions

        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            MockURLProtocol.lastRequest = request
            MockURLProtocol.capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")

            guard let (data, statusCode) = MockURLProtocol.mockResponse else {
                client?.urlProtocol(self, didFailWithError: NSError(domain: "Test", code: -1))
                return
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"],
            )!

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        // MARK: Static Functions

        static func reset() {
            mockResponse = nil
            lastRequest = nil
            capturedAuthorization = nil
        }
    }

    // MARK: Functions

    // MARK: Bearer Token Tests

    @Test
    func `Authorization header includes Bearer token`() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = try (
            data: JSONEncoder().encode([BookmarkSyncEntry]()),
            statusCode: 200,
        )

        let client = makeClient()
        _ = try await client.fetchSyncedBookmarks(since: nil)

        #expect(MockURLProtocol.capturedAuthorization == "Bearer test-token-123")
    }

    @Test
    func `Accept header is set to application/json`() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = try (
            data: JSONEncoder().encode([BookmarkSyncEntry]()),
            statusCode: 200,
        )

        let client = makeClient()
        _ = try await client.fetchSyncedBookmarks(since: nil)

        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    // MARK: Sync Endpoint Tests

    @Test
    func `Sync URL without since parameter for initial sync`() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = try (
            data: JSONEncoder().encode([BookmarkSyncEntry]()),
            statusCode: 200,
        )

        let client = makeClient()
        _ = try await client.fetchSyncedBookmarks(since: nil)

        let url = MockURLProtocol.lastRequest?.url
        #expect(url?.path == "/api/bookmarks/sync")
        #expect(url?.query == nil)
    }

    @Test
    func `Sync URL includes since parameter for incremental sync`() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = try (
            data: JSONEncoder().encode([BookmarkSyncEntry]()),
            statusCode: 200,
        )

        let client = makeClient()
        _ = try await client.fetchSyncedBookmarks(since: "2025-01-01T00:00:00Z")

        let url = MockURLProtocol.lastRequest?.url
        #expect(url?.path == "/api/bookmarks/sync")
        #expect(url?.query == "since=2025-01-01T00:00:00Z")
    }

    // MARK: Bookmark Detail Tests

    @Test
    func `Fetch bookmark detail constructs correct URL`() async throws {
        MockURLProtocol.reset()
        let detail = BookmarkDetail(
            id: "abc123",
            title: "Test",
            url: "https://example.com",
            created: "2025-06-15T14:30:00Z",
            labels: ["tech"],
            isArchived: false,
        )
        MockURLProtocol.mockResponse = try (
            data: JSONEncoder().encode(detail),
            statusCode: 200,
        )

        let client = makeClient()
        let result = try await client.fetchBookmark(id: "abc123")

        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/bookmarks/abc123")
        #expect(result.id == "abc123")
        #expect(result.title == "Test")
        #expect(result.url == "https://example.com")
    }

    // MARK: Error Handling Tests

    @Test
    func `401 response throws unauthorized error`() async {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = (data: Data(), statusCode: 401)

        let client = makeClient()

        do {
            _ = try await client.fetchSyncedBookmarks(since: nil)
            #expect(Bool(false), "Should have thrown")
        } catch let error as ReadeckError {
            if case .unauthorized = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false), "Expected unauthorized error, got: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test
    func `Non-200 response throws http error`() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = try (data: #require("Server error".data(using: .utf8)), statusCode: 500)

        let client = makeClient()

        do {
            _ = try await client.fetchSyncedBookmarks(since: nil)
            #expect(Bool(false), "Should have thrown")
        } catch let error as ReadeckError {
            if case let .httpError(statusCode, body) = error {
                #expect(statusCode == 500)
                #expect(body == "Server error")
            } else {
                #expect(Bool(false), "Expected httpError, got: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    private func makeClient() -> ReadeckClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return ReadeckClient(endpoint: "https://readeck.example.com", apiToken: "test-token-123", urlSession: session)
    }
}
