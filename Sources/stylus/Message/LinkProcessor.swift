import Foundation
#if canImport(LinkPresentation)
    import LinkPresentation
#endif
import RegexBuilder

// MARK: - LinkProcessor

struct LinkProcessor {
    // MARK: Static Properties

    /// Common URL tracking parameters to remove
    private static let trackingParameters: Set<String> = [
        // Google Analytics
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        // Google Ads
        "gclid", "gclsrc", "dclid",
        // Facebook
        "fbclid", "fbadid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        // Microsoft Bing
        "msclkid",
        // Amazon
        "tag", "ref_", "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t", "pf_rd_i", "pf_rd_m",
        // Twitter/X
        "twclid", "s", "t", "cn",
        // LinkedIn
        "trk", "trkCampaign", "trackingId",
        // HubSpot
        "hsa_cam", "hsa_grp", "hsa_mt", "hsa_src", "hsa_ad", "hsa_acc", "hsa_net", "hsa_kw", "hsa_tgt", "hsa_ver",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Adobe
        "s_cid", "s_kwcid",
        // Other common tracking
        "referrer", "affiliate_id", "campaign_id",
        // Analytics platforms
        "_ga", "_gl", "_ke", "vero_conv", "vero_id", "wickedid", "yclid",
    ]

    /// Tracking parameter prefixes that should be matched as prefixes
    private static let trackingPrefixes: Set<String> = [
        "pf_rd_", "ref_", "utm_", "fb_", "hsa_",
    ]

    // MARK: Functions

    /// Removes tracking parameters from a URL string
    func cleanTrackingParameters(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return urlString
        }

        // Filter out tracking parameters
        components.queryItems = components.queryItems?.filter { queryItem in
            let paramName = queryItem.name.lowercased()

            // Check exact matches first
            if Self.trackingParameters.contains(paramName) {
                return false
            }

            // Check prefix matches
            for prefix in Self.trackingPrefixes {
                if paramName.hasPrefix(prefix) {
                    return false
                }
            }

            return true
        }

        // If no query items remain, remove the query entirely
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }

        return components.url?.absoluteString ?? urlString
    }

    /// Extracts all HTTP/HTTPS URLs from the given text
    func extractURLs(from text: String) -> [String] {
        let urlRegex = Regex {
            "http"
            Optionally("s")
            "://"
            OneOrMore {
                CharacterClass.anyOf(
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%",
                )
            }
        }

        let matches = text.matches(of: urlRegex)
        return matches.map { match in
            var url = String(text[match.range])
            // Remove trailing punctuation that's likely sentence punctuation
            let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "\"", "'", "`", "}", ">"]
            while let lastChar = url.last, trailingPunctuation.contains(lastChar) {
                url = String(url.dropLast())
            }
            // Clean tracking parameters from the URL
            return cleanTrackingParameters(from: url)
        }
    }

    /// Fetches the title of a web page from the given URL
    func fetchPageTitle(
        from urlString: String,
        provider: LinkMetadataProviderProtocol,
    ) async throws -> (String?, URL)? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        print("fetching metadata for \(url)")
        let metadata = try await provider.fetchMetadata(for: url)
        return (metadata.title, metadata.url)
    }

    /// Processes text to wrap URLs with Markdown links
    func processLinks(
        in text: String,
        metadataProvider: @escaping @Sendable () -> LinkMetadataProviderProtocol = {
            #if canImport(LinkPresentation)
                let provider = LPMetadataProvider()
                provider.timeout = 5
                return provider
            #else
                fatalError("LinkPresentation not available on this platform")
            #endif
        },
    ) async -> String {
        // Extract raw URLs first to preserve original URLs for replacement
        let rawUrls = extractRawURLs(from: text)
        let cleanUrls = rawUrls.map { cleanTrackingParameters(from: $0) }

        guard !cleanUrls.isEmpty else {
            return text
        }

        var processedText = text
        var urlTitles: [String: String] = [:]

        // Fetch titles for all clean URLs
        await withTaskGroup(of: (String, String?).self) { group in
            for cleanUrl in cleanUrls {
                group.addTask {
                    let provider = metadataProvider()
                    guard let meta = try? await fetchPageTitle(
                        from: cleanUrl,
                        provider: provider,
                    ) else {
                        return (cleanUrl, nil)
                    }

                    return (meta.1.absoluteString, meta.0)
                }
            }

            for await (url, title) in group {
                if let title, !title.isEmpty {
                    urlTitles[url] = title
                }
            }
        }

        // Create mapping between raw URLs and clean URLs
        let urlMapping = zip(rawUrls, cleanUrls).reduce(into: [String: String]()) { result, pair in
            result[pair.0] = pair.1
        }

        // Get unique raw URLs and sort by length in descending order to avoid partial replacements
        let uniqueRawUrls = Array(Set(rawUrls)).sorted { $0.count > $1.count }

        // Replace raw URLs with Markdown links using clean URLs
        for rawUrl in uniqueRawUrls {
            guard let cleanUrl = urlMapping[rawUrl],
                  let title = urlTitles[cleanUrl]
            else {
                continue
            }

            let htmlLink = "[\(title)](\(cleanUrl))"
            processedText = processedText.replacing(rawUrl, with: htmlLink)
        }

        return processedText
    }

    /// Extracts URLs without cleaning tracking parameters (for internal use)
    private func extractRawURLs(from text: String) -> [String] {
        let urlRegex = Regex {
            "http"
            Optionally("s")
            "://"
            OneOrMore {
                CharacterClass.anyOf(
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%",
                )
            }
        }

        let matches = text.matches(of: urlRegex)
        return matches.map { match in
            var url = String(text[match.range])
            // Remove trailing punctuation that's likely sentence punctuation
            let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "\"", "'", "`", "}", ">"]
            while let lastChar = url.last, trailingPunctuation.contains(lastChar) {
                url = String(url.dropLast())
            }
            return url
        }
    }
}

// MARK: - LinkMetadata

struct LinkMetadata {
    var title: String?
    var url: URL
}

// MARK: - LinkMetadataProviderProtocol

protocol LinkMetadataProviderProtocol: Sendable {
    func fetchMetadata(for url: URL) async throws -> LinkMetadata
}

// MARK: - LPMetadataProvider + LinkMetadataProviderProtocol

#if canImport(LinkPresentation)
    extension LPMetadataProvider: LinkMetadataProviderProtocol {
        func fetchMetadata(for url: URL) async throws -> LinkMetadata {
            let meta = try await startFetchingMetadata(for: url)
            return .init(title: meta.title, url: meta.url ?? url)
        }
    }
#endif
