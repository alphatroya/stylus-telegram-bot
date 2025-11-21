import Foundation

#if canImport(LinkPresentation)
    import LinkPresentation
#endif

// MARK: - LinkProcessor

struct LinkProcessor {
    // MARK: Properties

    #if canImport(LinkPresentation)
        private let metadataProvider: LinkMetadataProviderProtocol

        // MARK: Initialization

        init(metadataProvider: LinkMetadataProviderProtocol = LPMetadataProvider()) {
            self.metadataProvider = metadataProvider
        }
    #else
        // Fallback for platforms without LinkPresentation
        init() {}
    #endif

    // MARK: Functions

    // MARK: Methods

    /// Extracts all HTTP/HTTPS URLs from the given text
    func extractURLs(from text: String) -> [String] {
        // Regex pattern to match HTTP and HTTPS URLs
        // Excludes trailing punctuation that's likely sentence punctuation
        let pattern = #"https?://[^\s<>\"{}|\\^`\[\]]+(?<![.,;:!?)\]])"#

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

        #if canImport(LinkPresentation)
            let metadata = try await metadataProvider.startFetchingMetadata(for: url)
            return metadata.title
        #else
            // Fallback: return nil on non-macOS platforms
            return nil
        #endif
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

        // Get unique URLs and sort by length in descending order to avoid partial replacements
        let uniqueUrls = Array(Set(urls)).sorted { $0.count > $1.count }

        // Replace URLs with HTML anchor tags
        for url in uniqueUrls {
            let title = urlTitles[url] ?? url
            let escapedTitle = escapeHTML(title)
            let escapedURL = escapeHTML(url)
            let htmlLink = "<a href=\"\(escapedURL)\">\(escapedTitle)</a>"
            // Replace all occurrences of this URL
            processedText = processedText.replacingOccurrences(of: url, with: htmlLink)
        }

        return processedText
    }
}

#if canImport(LinkPresentation)

    // MARK: - LinkMetadataProviderProtocol

    protocol LinkMetadataProviderProtocol: Sendable {
        func startFetchingMetadata(for url: URL) async throws -> LPLinkMetadata
    }

    // MARK: - LPMetadataProvider + LinkMetadataProviderProtocol

    extension LPMetadataProvider: LinkMetadataProviderProtocol {
        func startFetchingMetadata(for url: URL) async throws -> LPLinkMetadata {
            try await withCheckedThrowingContinuation { continuation in
                self.startFetchingMetadata(for: url) { metadata, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
        }
    }
#endif
