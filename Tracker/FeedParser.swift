import Foundation

/// A small RSS 2.0 / Atom parser built on XMLParser.
///
/// Feeds in the wild are inconsistent about where they put the image, so this
/// checks `media:thumbnail`, `media:content` and `enclosure` in turn.
final class FeedParser: NSObject {
    private var items: [FeedItem] = []
    private var sourceName: String

    private var element = ""
    private var insideItem = false

    private var title = ""
    private var descriptionText = ""
    private var contentText = ""
    private var link = ""
    private var dateText = ""
    private var imageText = ""
    private var guid = ""

    init(sourceName: String) {
        self.sourceName = sourceName
    }

    func parse(data: Data) -> [FeedItem] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()
        return items
    }

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static func date(from text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }

    /// Feeds vary wildly: some put a one-line teaser in `description` and the
    /// full article in `content:encoded`, some only have one. Take whichever is
    /// meatier, then trim to something that reads well on a card.
    static func bestSummary(description: String, content: String) -> String {
        let a = plainText(description)
        let b = plainText(content)
        let chosen = b.count > a.count ? b : a
        return truncate(deduplicateSentences(chosen), to: 600)
    }

    /// Some feeds repeat the teaser inside the body, so the same sentences show
    /// up twice in a row. Drop any sentence we've already seen.
    static func deduplicateSentences(_ text: String) -> String {
        let parts = text.split(separator: ".", omittingEmptySubsequences: true)
        var seen = Set<String>()
        var kept: [String] = []

        for part in parts {
            let sentence = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }
            let key = sentence.lowercased()
            // Very short fragments ("Inc", "Dr") aren't worth de-duplicating.
            if sentence.count > 12, !seen.insert(key).inserted { continue }
            kept.append(sentence)
        }

        guard !kept.isEmpty else { return text }
        return kept.joined(separator: ". ") + "."
    }

    /// Pulls the first `src` out of an <img> tag.
    static func firstImage(inHTML html: String) -> String? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "<img[^>]+src=[\"']([^\"']+)[\"']",
                options: .caseInsensitive
            ),
            let match = regex.firstMatch(
                in: html,
                range: NSRange(html.startIndex..., in: html)
            ),
            let range = Range(match.range(at: 1), in: html)
        else { return nil }

        let candidate = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.hasPrefix("https") ? candidate : nil
    }

    /// Cuts at a word boundary rather than mid-word.
    private static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        if let lastSpace = cut.lastIndex(of: " ") {
            return cut[..<lastSpace].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return cut + "…"
    }

    /// Feed summaries are often HTML. Strip the tags and unescape the basics.
    static func plainText(_ raw: String) -> String {
        var text = raw.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&#8217;": "’",
            "&#8216;": "‘", "&#8220;": "“", "&#8221;": "”", "&#8230;": "…"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension FeedParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        element = elementName

        if elementName == "item" || elementName == "entry" {
            insideItem = true
            title = ""; descriptionText = ""; contentText = ""
            link = ""; dateText = ""; imageText = ""; guid = ""
        }

        guard insideItem else { return }

        // Atom puts the article URL in an attribute rather than the body.
        if elementName == "link", let href = attributeDict["href"],
           attributeDict["rel"] == nil || attributeDict["rel"] == "alternate" {
            link = href
        }

        if imageText.isEmpty {
            switch elementName {
            case "media:thumbnail", "media:content":
                if let url = attributeDict["url"] { imageText = url }
            case "enclosure":
                if let url = attributeDict["url"],
                   attributeDict["type"]?.hasPrefix("image") ?? true {
                    imageText = url
                }
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch element {
        case "title": title += string
        case "description", "summary": descriptionText += string
        case "content:encoded", "content": contentText += string
        case "link": link += string
        case "pubDate", "published", "updated": dateText += string
        case "guid", "id": guid += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "item" || elementName == "entry" else { return }
        insideItem = false

        let cleanTitle = Self.plainText(title)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let url = URL(string: trimmedLink) else { return }

        // Several feeds (NPR among them) carry no media attributes and instead
        // embed the artwork as an <img> inside the HTML body.
        let resolvedImage = imageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.firstImage(inHTML: contentText + descriptionText)
            : imageText.trimmingCharacters(in: .whitespacesAndNewlines)

        let identifier = guid.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(
            FeedItem(
                id: identifier.isEmpty ? trimmedLink : identifier,
                title: cleanTitle,
                summary: Self.bestSummary(description: descriptionText, content: contentText),
                link: url,
                imageURL: resolvedImage.flatMap(URL.init(string:)),
                published: Self.date(from: dateText),
                sourceName: sourceName
            )
        )
    }
}
