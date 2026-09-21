import Foundation
import Observation
import SwiftUI

/// Fetches the selected RSS feeds, interleaves them, and caches the result so
/// the feed still has something to show when you're offline.
///
/// Two things keep the feed from looking the same every day: stories you've
/// already scrolled past are remembered and filtered out, and each topic pulls
/// from several publishers so the pool doesn't run dry.
@MainActor
@Observable
final class FeedStore {
    static let shared = FeedStore()

    private(set) var items: [FeedItem] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var lastRefreshed: Date?
    private(set) var lastError: String?
    /// True when a fetch came back with nothing you haven't already read.
    private(set) var reachedEnd = false

    @ObservationIgnored private var hasLoadedCache = false
    @ObservationIgnored private var seen: [String: Date] = [:]
    @ObservationIgnored private var hasLoadedSeen = false

    /// How many read-story ids to remember. Roughly a month of heavy reading.
    private let seenLimit = 1500
    /// Forget anything older than this, so stories can eventually resurface.
    private let seenLifetime: TimeInterval = 45 * 86_400

    private init() {}

    // MARK: - Selection

    var topics: Set<FeedTopic> {
        SettingsStore.shared.feedTopics
    }

    var customFeeds: [CustomFeed] {
        SettingsStore.shared.customFeeds
    }

    var seenCount: Int { seen.count }

    private var sources: [FeedSource] {
        let topicSources = topics.flatMap(\.sources)
        let custom = customFeeds.map { FeedSource(name: $0.name, url: $0.url) }
        // Topics overlap (Al Jazeera is in both Top and World), so de-duplicate.
        var unique: [FeedSource] = []
        for source in topicSources + custom where !unique.contains(where: { $0.url == source.url }) {
            unique.append(source)
        }
        return unique
    }

    // MARK: - Loading

    /// Called when the Feed tab appears.
    func loadIfNeeded() async {
        loadSeenIfNeeded()

        if !hasLoadedCache {
            hasLoadedCache = true
            loadCache()
        }

        let isStale = lastRefreshed.map { Date().timeIntervalSince($0) > 900 } ?? true
        if items.isEmpty || isStale {
            await refresh()
        }
    }

    /// Replaces the feed with unread stories. Used on pull-to-refresh, on topic
    /// changes, and when the cache has gone stale.
    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        loadSeenIfNeeded()

        let fetched = await fetchAll()
        isLoading = false

        guard !fetched.isEmpty else {
            if items.isEmpty {
                lastError = sources.isEmpty
                    ? "No topics selected."
                    : "Couldn't reach the feeds. Check your connection."
            }
            return
        }

        let unread = fetched.filter { seen[$0.id] == nil }
        items = unread.isEmpty ? fetched : unread
        reachedEnd = unread.isEmpty
        lastRefreshed = Date()
        saveCache()
    }

    /// Called when you hit the bottom. Refetches and appends anything you
    /// haven't already got, rather than dead-ending.
    func loadMore() async {
        guard !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        loadSeenIfNeeded()

        let fetched = await fetchAll()
        let existing = Set(items.map(\.id))
        let fresh = fetched.filter { seen[$0.id] == nil && !existing.contains($0.id) }

        if fresh.isEmpty {
            reachedEnd = true
        } else {
            items.append(contentsOf: fresh)
            reachedEnd = false
            lastRefreshed = Date()
            saveCache()
        }

        isLoadingMore = false
    }

    /// Forget the read history, so everything is fair game again.
    func clearHistory() async {
        seen = [:]
        saveSeen()
        reachedEnd = false
        await refresh(force: true)
    }

    /// Marked as a card actually comes on screen, so "read" means seen.
    func markSeen(_ item: FeedItem) {
        guard seen[item.id] == nil else { return }
        seen[item.id] = Date()
        saveSeen()
    }

    private func fetchAll() async -> [FeedItem] {
        let list = sources
        guard !list.isEmpty else { return [] }

        var collected: [[FeedItem]] = []

        // Fetch in parallel; one dead feed shouldn't hold up or sink the rest.
        await withTaskGroup(of: [FeedItem].self) { group in
            for source in list {
                group.addTask { await Self.fetch(source) }
            }
            for await result in group where !result.isEmpty {
                collected.append(result)
            }
        }

        return Self.interleave(collected)
    }

    private nonisolated static func fetch(_ source: FeedSource) async -> [FeedItem] {
        guard let url = URL(string: source.url) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bloom Day/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return []
            }
            return FeedParser(sourceName: source.name).parse(data: data)
        } catch {
            return []
        }
    }

    /// Round-robin across publishers so one prolific feed can't dominate the top
    /// of the scroll, then sort each round by recency.
    private static func interleave(_ groups: [[FeedItem]]) -> [FeedItem] {
        guard !groups.isEmpty else { return [] }

        var result: [FeedItem] = []
        var seenIDs = Set<String>()
        let longest = groups.map(\.count).max() ?? 0

        for index in 0..<longest {
            var round: [FeedItem] = []
            for group in groups where group.indices.contains(index) {
                let item = group[index]
                if seenIDs.insert(item.id).inserted {
                    round.append(item)
                }
            }
            round.sort { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
            result.append(contentsOf: round)
        }

        return Array(result.prefix(400))
    }

    // MARK: - Read history

    private var seenURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("feed-seen.json")
    }

    private func loadSeenIfNeeded() {
        guard !hasLoadedSeen else { return }
        hasLoadedSeen = true

        guard
            let seenURL,
            let data = try? Data(contentsOf: seenURL),
            let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }

        let cutoff = Date().addingTimeInterval(-seenLifetime)
        seen = decoded.filter { $0.value > cutoff }
    }

    private func saveSeen() {
        // Trim oldest first so the file can't grow without bound.
        if seen.count > seenLimit {
            let keep = seen.sorted { $0.value > $1.value }.prefix(seenLimit)
            seen = Dictionary(uniqueKeysWithValues: Array(keep))
        }

        guard let seenURL else { return }
        try? FileManager.default.createDirectory(
            at: seenURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder().encode(seen).write(to: seenURL, options: .atomic)
    }

    // MARK: - Cache

    private var cacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("feed-cache.json")
    }

    private struct Cache: Codable {
        let items: [FeedItem]
        let refreshed: Date
    }

    private func saveCache() {
        guard let cacheURL else { return }
        let cache = Cache(items: items, refreshed: lastRefreshed ?? Date())
        try? JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
    }

    private func loadCache() {
        guard
            let cacheURL,
            let data = try? Data(contentsOf: cacheURL),
            let cache = try? JSONDecoder().decode(Cache.self, from: data)
        else { return }

        items = cache.items
        lastRefreshed = cache.refreshed
    }
}
