import Foundation
import LinkPresentation
import RegexBuilder

// MARK: - LinkProcessor

struct LinkProcessor {
    // MARK: Properties

    private let metadataProvider: LinkMetadataProviderProtocol

    // MARK: Lifecycle

    // MARK: Initialization

    init(metadataProvider: LinkMetadataProviderProtocol = LPMetadataProvider()) {
        self.metadataProvider = metadataProvider
    }

    // MARK: Functions

    // MARK: Methods

    /// Extracts all HTTP/HTTPS URLs from the given text
    func extractURLs(from text: String) -> [String] {
        let urlRegex = Regex {
            "http"
            Optionally("s")
            "://"
            OneOrMore {
                CharacterClass.anyOf("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%")
            }
        }

        let matches = text.matches(of: urlRegex)
        return matches.map { match in
            let url = String(text[match.range])
            // Remove trailing punctuation that's likely sentence punctuation
            while let lastChar = url.last, [".", ",", ";", ":", "!", "?", ")", "]", "\""].contains(lastChar) {
                return String(url.dropLast())
            }
            return url
        }
    }

    /// Fetches the title of a web page from the given URL
    func fetchPageTitle(from urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        let metadata = try await metadataProvider.fetchMetadata(for: url)
        return metadata.title
    }

    /// Processes text to wrap URLs with Markdown links
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
            guard let title = urlTitles[url] else {
                continue
            }

            let htmlLink = "[\(title)](\(url))"
            processedText = processedText.replacing(url, with: htmlLink)
        }

        return processedText
    }
}

// MARK: - LinkMetadata

struct LinkMetadata: Sendable {
    var title: String?
}

// MARK: - LinkMetadataProviderProtocol

protocol LinkMetadataProviderProtocol: Sendable {
    func fetchMetadata(for url: URL) async throws -> LinkMetadata
}

// MARK: - LPMetadataProvider + LinkMetadataProviderProtocol

extension LPMetadataProvider: LinkMetadataProviderProtocol {
    func fetchMetadata(for url: URL) async throws -> LinkMetadata {
        let meta = try await startFetchingMetadata(for: url)
        return .init(title: meta.title)
    }
}
