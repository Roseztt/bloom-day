import SwiftUI

struct FeedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsStore.shared
    @State private var store = FeedStore.shared

    @State private var newFeedName = ""
    @State private var newFeedURL = ""
    @State private var urlError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(FeedTopic.allCases) { topic in
                        Button {
                            toggle(topic)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: topic.symbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(topic.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(topic.label)
                                        .foregroundStyle(Bloom.ink)
                                    Text(topic.sourceSummary)
                                        .font(BloomFont.body(11))
                                        .foregroundStyle(Bloom.inkSoft)
                                }

                                Spacer()

                                if settings.feedTopics.contains(topic) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Bloom.pink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Topics")
                } footer: {
                    Text("Several publishers per topic, fetched straight from their public RSS. Stories you've already scrolled past are remembered and won't come back.")
                }

                Section {
                    ForEach(settings.customFeeds) { feed in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.name).foregroundStyle(Bloom.ink)
                            Text(feed.url)
                                .font(BloomFont.body(11))
                                .foregroundStyle(Bloom.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    .onDelete { offsets in
                        settings.customFeeds.remove(atOffsets: offsets)
                        Task { await store.refresh(force: true) }
                    }

                    TextField("Name (e.g. Campus news)", text: $newFeedName)
                    TextField("https://example.com/feed.xml", text: $newFeedURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Add feed", action: addCustomFeed)
                        .disabled(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Your own feeds")
                } footer: {
                    if let urlError {
                        Text(urlError).foregroundStyle(Bloom.pink)
                    } else {
                        Text("Paste any RSS or Atom URL — a course blog, a campus paper, a newsletter.")
                    }
                }

                Section {
                    LabeledContent("Stories loaded", value: "\(store.items.count)")
                    if let refreshed = store.lastRefreshed {
                        LabeledContent(
                            "Last updated",
                            value: refreshed.formatted(date: .omitted, time: .shortened)
                        )
                    }
                    LabeledContent("Stories read", value: "\(store.seenCount)")
                    Button("Refresh now") {
                        Task { await store.refresh(force: true) }
                    }
                    if store.seenCount > 0 {
                        Button("Clear read history") {
                            Task { await store.clearHistory() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BloomBackground())
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Bloom.pink)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ topic: FeedTopic) {
        var topics = settings.feedTopics
        if topics.contains(topic) {
            topics.remove(topic)
        } else {
            topics.insert(topic)
        }
        settings.feedTopics = topics
        Task { await store.refresh(force: true) }
    }

    private func addCustomFeed() {
        let trimmed = newFeedURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            urlError = "That doesn't look like a URL."
            return
        }
        // App Transport Security blocks plain HTTP, so catch it here with a clear
        // message rather than letting the fetch fail silently later.
        guard scheme == "https" else {
            urlError = "Needs to start with https://"
            return
        }

        let name = newFeedName.trimmingCharacters(in: .whitespaces)
        settings.customFeeds.append(
            CustomFeed(name: name.isEmpty ? (url.host ?? "Custom") : name, url: trimmed)
        )
        newFeedName = ""
        newFeedURL = ""
        urlError = nil
        Task { await store.refresh(force: true) }
    }
}
