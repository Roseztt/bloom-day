import SwiftUI

/// A publisher feed.
struct FeedSource: Hashable {
    let name: String
    let url: String
}

/// A news topic and the public RSS feeds behind it.
///
/// RSS deliberately, rather than a news API: no key to embed in the binary, no
/// signup, no free tier that can start charging or get revoked.
///
/// Several publishers per topic on purpose — one feed only carries its last
/// ~20-40 stories, so a single source runs dry fast and starts repeating.
enum FeedTopic: String, CaseIterable, Identifiable, Codable {
    case top
    case world
    case science
    case technology
    case health
    case business
    case education

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: return "Top stories"
        case .world: return "World"
        case .science: return "Science"
        case .technology: return "Technology"
        case .health: return "Health"
        case .business: return "Business"
        case .education: return "Education"
        }
    }

    var sources: [FeedSource] {
        switch self {
        case .top:
            return [
                FeedSource(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml"),
                FeedSource(name: "NPR", url: "https://feeds.npr.org/1001/rss.xml"),
                FeedSource(name: "Sky News", url: "https://feeds.skynews.com/feeds/rss/home.xml"),
                FeedSource(name: "Al Jazeera", url: "https://www.aljazeera.com/xml/rss/all.xml")
            ]
        case .world:
            return [
                FeedSource(name: "BBC World", url: "https://feeds.bbci.co.uk/news/world/rss.xml"),
                FeedSource(name: "NPR World", url: "https://feeds.npr.org/1004/rss.xml"),
                FeedSource(name: "The Guardian", url: "https://www.theguardian.com/world/rss"),
                FeedSource(name: "Al Jazeera", url: "https://www.aljazeera.com/xml/rss/all.xml")
            ]
        case .science:
            return [
                FeedSource(name: "NPR Science", url: "https://feeds.npr.org/1007/rss.xml"),
                FeedSource(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/science"),
                FeedSource(name: "Guardian Science", url: "https://www.theguardian.com/science/rss"),
                FeedSource(name: "Phys.org", url: "https://phys.org/rss-feed/"),
                FeedSource(name: "BBC Science", url: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")
            ]
        case .technology:
            return [
                FeedSource(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index"),
                FeedSource(name: "The Verge", url: "https://www.theverge.com/rss/index.xml"),
                FeedSource(name: "Guardian Tech", url: "https://www.theguardian.com/uk/technology/rss"),
                FeedSource(name: "BBC Tech", url: "https://feeds.bbci.co.uk/news/technology/rss.xml"),
                FeedSource(name: "Hacker News", url: "https://hnrss.org/frontpage")
            ]
        case .health:
            return [
                FeedSource(name: "NPR Health", url: "https://feeds.npr.org/1128/rss.xml"),
                FeedSource(name: "BBC Health", url: "https://feeds.bbci.co.uk/news/health/rss.xml"),
                FeedSource(name: "Guardian Health", url: "https://www.theguardian.com/society/health/rss")
            ]
        case .business:
            return [
                FeedSource(name: "NPR Business", url: "https://feeds.npr.org/1006/rss.xml"),
                FeedSource(name: "BBC Business", url: "https://feeds.bbci.co.uk/news/business/rss.xml"),
                FeedSource(name: "Guardian Business", url: "https://www.theguardian.com/uk/business/rss")
            ]
        case .education:
            return [
                FeedSource(name: "NPR Education", url: "https://feeds.npr.org/1013/rss.xml"),
                FeedSource(name: "BBC Education", url: "https://feeds.bbci.co.uk/news/education/rss.xml"),
                FeedSource(name: "Guardian Education", url: "https://www.theguardian.com/education/rss")
            ]
        }
    }

    var sourceSummary: String {
        let names = sources.prefix(3).map(\.name)
        let extra = sources.count - names.count
        return extra > 0
            ? names.joined(separator: ", ") + " +\(extra)"
            : names.joined(separator: ", ")
    }

    var symbol: String {
        switch self {
        case .top: return "newspaper.fill"
        case .world: return "globe"
        case .science: return "atom"
        case .technology: return "cpu"
        case .health: return "heart.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .education: return "graduationcap.fill"
        }
    }

    var tint: Color {
        switch self {
        case .top: return Bloom.pink
        case .world: return Bloom.lavender
        case .science: return Bloom.mint
        case .technology: return Bloom.lavender
        case .health: return Bloom.pink
        case .business: return Bloom.peach
        case .education: return Bloom.mint
        }
    }
}

/// A feed the user added themselves.
struct CustomFeed: Codable, Identifiable, Hashable {
    var id: String { url }
    var name: String
    var url: String
}

/// One story.
struct FeedItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let link: URL
    let imageURL: URL?
    let published: Date?
    let sourceName: String

    var relativeTime: String? {
        guard let published else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: published, relativeTo: Date())
    }
}
