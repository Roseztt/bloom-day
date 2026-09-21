import SwiftUI
import SafariServices

struct FeedView: View {
    @State private var store = FeedStore.shared
    @State private var settings = SettingsStore.shared
    @State private var reading: FeedItem?
    @State private var showingTopics = false
    @State private var scrollID: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Group {
                    if store.items.isEmpty {
                        emptyState
                    } else {
                        pager(size: geo.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(BloomBackground())
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.loadIfNeeded() }
            .sheet(item: $reading) { item in
                SafariView(url: item.link).ignoresSafeArea()
            }
            .sheet(isPresented: $showingTopics) {
                FeedSettingsView()
            }
        }
    }

    // MARK: - Pager

    private func pager(size: CGSize) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(store.items) { item in
                    FeedCard(item: item, size: size) { reading = item }
                        .frame(width: size.width, height: size.height)
                        .onAppear { store.markSeen(item) }
                }

                EndOfFeedCard(
                    store: store,
                    onBackToTop: { scrollID = store.items.first?.id }
                )
                .frame(width: size.width, height: size.height)
                // Reaching the bottom fetches more rather than dead-ending.
                .onAppear { Task { await store.loadMore() } }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollID)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { topBar }
        .refreshable { await store.refresh(force: true) }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("Today's reading")
                .font(BloomFont.display(19))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 1)

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }

            Button {
                showingTopics = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            BunnyView(pose: .study)
                .frame(width: 110, height: 110)

            Text(store.isLoading ? "Fetching stories…" : "Nothing to read yet")
                .font(BloomFont.heading(17))
                .foregroundStyle(Bloom.ink)

            Text(store.lastError ?? "Pick a few topics and I'll keep this filled.")
                .font(BloomFont.note(13))
                .foregroundStyle(Bloom.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !store.isLoading {
                HStack(spacing: 10) {
                    Button("Choose topics") { showingTopics = true }
                        .font(BloomFont.body(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Bloom.pink, in: Capsule())

                    Button("Try again") {
                        Task { await store.refresh(force: true) }
                    }
                    .font(BloomFont.body(14, weight: .semibold))
                    .foregroundStyle(Bloom.pink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Bloom.pinkSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - One full-screen story

private struct FeedCard: View {
    let item: FeedItem
    let size: CGSize
    var onRead: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            // Scrim, so white text stays readable over any photograph.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0), location: 0.08),
                    .init(color: .black.opacity(0.35), location: 0.32),
                    .init(color: .black.opacity(0.78), location: 0.58),
                    .init(color: .black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(item.sourceName)
                        .font(BloomFont.body(11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Bloom.pink.opacity(0.9), in: Capsule())

                    if let time = item.relativeTime {
                        Text(time)
                            .font(BloomFont.body(12))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Text(item.title)
                    .font(BloomFont.display(27))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(BloomFont.body(15))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(2)
                        .lineLimit(10)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onRead) {
                    Label("Read the story", systemImage: "arrow.up.right")
                        .font(BloomFont.body(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Bloom.pink, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            // Clear of the floating tab bar.
            .padding(.bottom, 118)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var background: some View {
        if let imageURL = item.imageURL {
            AsyncImage(url: imageURL, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                default:
                    Self.fallbackGradient
                }
            }
        } else {
            Self.fallbackGradient
        }
    }

    /// Used when a story has no artwork, so every page still fills the screen.
    private static var fallbackGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.62, green: 0.48, blue: 0.72),
                Color(red: 0.86, green: 0.52, blue: 0.62)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// The last page. Tries to pull in more before admitting there's nothing left.
private struct EndOfFeedCard: View {
    @Bindable var store: FeedStore
    var onBackToTop: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            BunnyView(pose: store.isLoadingMore ? .study : .completed)
                .frame(width: 118, height: 118)

            Text(store.isLoadingMore ? "Looking for more…" : "You're all caught up")
                .font(BloomFont.display(23))
                .foregroundStyle(Bloom.ink)

            Text(caption)
                .font(BloomFont.note(14))
                .foregroundStyle(Bloom.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 42)

            if !store.isLoadingMore {
                VStack(spacing: 10) {
                    Button {
                        Task { await store.refresh(force: true) }
                    } label: {
                        Label("Check again", systemImage: "arrow.clockwise")
                            .font(BloomFont.body(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Bloom.pink, in: Capsule())
                    }

                    Button(action: onBackToTop) {
                        Label("Back to the top", systemImage: "arrow.up")
                            .font(BloomFont.body(15, weight: .semibold))
                            .foregroundStyle(Bloom.pink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Bloom.pinkSoft, in: Capsule())
                    }

                    if store.seenCount > 0 {
                        Button {
                            Task { await store.clearHistory() }
                        } label: {
                            Text("Show stories I've already read")
                                .font(BloomFont.body(13))
                                .foregroundStyle(Bloom.inkSoft)
                        }
                        .padding(.top, 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BloomBackground())
    }

    private var caption: String {
        if store.isLoadingMore {
            return "Checking your feeds for anything new."
        }
        return store.seenCount > 0
            ? "That's every story you haven't already read. New ones appear as your feeds publish them."
            : "Nothing more to scroll. Now go do the thing you wrote down."
    }
}

/// In-app browser, so tapping a story doesn't throw you out to Safari.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Bloom.pink)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
