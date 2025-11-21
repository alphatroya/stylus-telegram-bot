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
        return decodeHTMLEntities(title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes common HTML entities in a string
    func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Common named entities
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Decode numeric entities (&#123; and &#xAB;)
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let numRange = Range(match.range(at: 1), in: result),
                   let num = Int(result[numRange]),
                   let scalar = UnicodeScalar(num)
                {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }

    /// Escapes HTML special characters in a string
    func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
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

        // Sort URLs by length in descending order to avoid partial replacements
        let sortedUrls = urls.sorted { $0.count > $1.count }

        // Replace URLs with HTML anchor tags
        for url in sortedUrls {
            let title = urlTitles[url] ?? url
            let escapedTitle = escapeHTML(title)
            let escapedURL = escapeHTML(url)
            let htmlLink = "<a href=\"\(escapedURL)\">\(escapedTitle)</a>"
            // Only replace exact matches, not partial
            if let range = processedText.range(of: url) {
                processedText.replaceSubrange(range, with: htmlLink)
            }
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
