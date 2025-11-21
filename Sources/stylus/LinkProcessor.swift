import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - LinkProcessor

struct LinkProcessor {
    // MARK: Properties

    var urlSession: URLSessionProtocol

    // MARK: Lifecycle

    // MARK: Initialization

    init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
    }

    // MARK: Functions

    // MARK: Methods

    /// Extracts all HTTP/HTTPS URLs from the given text
    func extractURLs(from text: String) -> [String] {
        // Regex pattern to match HTTP and HTTPS URLs
        let pattern = #"https?://[^\s<>\"{}|\\^`\[\]]+"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }

            return String(text[range])
        }
    }

    /// Fetches the title of a web page from the given URL
    func fetchPageTitle(from urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        // Add user agent to avoid being blocked
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent",
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            return nil
        }

        // Try to extract title from HTML
        guard let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        return extractTitle(from: html)
    }

    /// Extracts the title from HTML content
    func extractTitle(from html: String) -> String? {
        // Look for <title> tag
        let pattern = #"<title[^>]*>(.*?)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let title = String(html[titleRange])
        // Decode HTML entities and clean up whitespace
        return title
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Processes text to wrap URLs with HTML anchor tags
    func processLinks(in text: String) async -> String {
        let urls = extractURLs(from: text)

        guard !urls.isEmpty else {
            return text
        }

        var processedText = text
        var urlTitles: [String: String] = [:]

        // Fetch titles for all URLs
        await withTaskGroup(of: (String, String?).self) { group in
            for url in urls {
                group.addTask {
                    let title = try? await fetchPageTitle(from: url)
                    return (url, title)
                }
            }

            for await (url, title) in group {
                if let title, !title.isEmpty {
                    urlTitles[url] = title
                }
            }
        }

        // Replace URLs with HTML anchor tags
        for url in urls {
            let title = urlTitles[url] ?? url
            let htmlLink = "<a href=\"\(url)\">\(title)</a>"
            processedText = processedText.replacingOccurrences(of: url, with: htmlLink)
        }

        return processedText
    }
}

// MARK: - URLSessionProtocol

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession + URLSessionProtocol

extension URLSession: URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
            // Linux implementation
            return try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data, let response else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    continuation.resume(returning: (data, response))
                }
                task.resume()
            }
        #else
            // macOS/iOS implementation
            return try await data(for: request, delegate: nil)
        #endif
    }
}
