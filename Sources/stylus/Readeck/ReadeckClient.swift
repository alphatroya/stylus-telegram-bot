import Foundation

// MARK: - ReadeckClientProtocol

/// Protocol for Readeck API client, allowing mocking in tests.
protocol ReadeckClientProtocol: Sendable {
    func fetchSyncedBookmarks(since: String?) async throws -> [BookmarkSyncEntry]
    func fetchBookmark(id: String) async throws -> BookmarkDetail
}

// MARK: - ReadeckError

enum ReadeckError: Error, LocalizedError {
    case unauthorized
    case invalidEndpoint(String)
    case networkError(Error)
    case decodingError(Error)
    case httpError(statusCode: Int, body: String?)

    // MARK: Computed Properties

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Readeck API returned 401 Unauthorized. Check that your readeckApiToken is valid and not expired."
        case let .invalidEndpoint(endpoint):
            "Invalid Readeck endpoint: '\(endpoint)'. Ensure readeckEndpoint is a valid URL."
        case let .networkError(error):
            "Network error communicating with Readeck: \(error.localizedDescription)"
        case let .decodingError(error):
            "Failed to decode Readeck API response: \(error.localizedDescription)"
        case let .httpError(statusCode, body):
            "Readeck API returned HTTP \(statusCode)\(body.map { ": \($0.prefix(200))" } ?? "")"
        }
    }
}

// MARK: - ReadeckClient

/// HTTP client for the Readeck REST API.
///
/// Uses `URLSession` for network requests with Bearer token authentication.
/// Automatically uses an insecure session for localhost endpoints to support
/// self-signed certificates common in local development.
struct ReadeckClient: ReadeckClientProtocol {
    // MARK: Properties

    private let endpoint: String
    private let apiToken: String
    private let urlSession: URLSession

    // MARK: Lifecycle

    init(endpoint: String, apiToken: String, urlSession: URLSession? = nil) {
        self.endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiToken = apiToken
        if let urlSession {
            self.urlSession = urlSession
        } else {
            self.urlSession = .shared
        }
    }

    // MARK: Functions

    /// Fetches bookmark sync entries that have changed since the given timestamp.
    ///
    /// - Parameter since: ISO 8601 timestamp for incremental sync. Pass `nil` for initial full sync.
    /// - Returns: Array of sync entries with their IDs, timestamps, and change types.
    func fetchSyncedBookmarks(since: String?) async throws -> [BookmarkSyncEntry] {
        var urlComponents = baseURLComponents()
        urlComponents.path = "/api/bookmarks/sync"

        if let since {
            urlComponents.queryItems = [URLQueryItem(name: "since", value: since)]
        }

        let request = try makeRequest(url: urlComponents.url!)
        let data = try await performRequest(request)
        return try decode([BookmarkSyncEntry].self, from: data)
    }

    /// Fetches full bookmark details for a given bookmark ID.
    ///
    /// - Parameter id: The Readeck bookmark ID.
    /// - Returns: The full bookmark details including title, URL, labels, etc.
    func fetchBookmark(id: String) async throws -> BookmarkDetail {
        var urlComponents = baseURLComponents()
        urlComponents.path = "/api/bookmarks/\(id)"

        let request = try makeRequest(url: urlComponents.url!)
        let data = try await performRequest(request)
        return try decode(BookmarkDetail.self, from: data)
    }

    private func baseURLComponents() -> URLComponents {
        guard let components = URLComponents(string: endpoint) else {
            return URLComponents()
        }

        return components
    }

    private func makeRequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReadeckError.networkError(
                    NSError(domain: "Readeck", code: -1, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"]),
                )
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                return data
            case 401:
                throw ReadeckError.unauthorized
            default:
                let body = String(data: data, encoding: .utf8)
                throw ReadeckError.httpError(statusCode: httpResponse.statusCode, body: body)
            }
        } catch let error as ReadeckError {
            throw error
        } catch {
            throw ReadeckError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ReadeckError.decodingError(error)
        }
    }
}

// MARK: - InsecureSessionDelegate

/// A URLSession delegate that trusts self-signed certificates for localhost connections.
///
/// This is needed because local Readeck instances typically use self-signed TLS certificates
/// that would otherwise be rejected by the default URLSession trust evaluation.
private final class InsecureSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard host == "localhost" || host == "127.0.0.1" || host == "::1" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the trust so macOS doesn't reject it outright, then accept the credential
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            // Even if evaluation fails (self-signed), accept it for localhost
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
