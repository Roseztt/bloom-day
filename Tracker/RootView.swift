import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = SettingsStore.shared
    @State private var selection = 0

    var body: some View {
        // Deliberately a plain TabView: on iOS 26 the system gives this the Liquid
        // Glass floating bar and its scroll-away animation for free, and any custom
        // bar or UITabBar appearance override would throw that away.
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(1)

            FeedView()
                .tabItem { Label("Feed", systemImage: "newspaper.fill") }
                .tag(2)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Bloom.pink)
        .preferredColorScheme(settings.colorScheme)
        .bloomTabBarBehavior()
        .task {
            #if DEBUG
            DemoData.seedIfRequested()
            selection = DemoData.startTab
            #endif
            _ = await NotificationManager.shared.requestAuthorization()
            #if DEBUG
            await DemoCalendar.seedIfRequested()
            #endif
            // Refresh the calendar cache first so the schedule below can see it.
            CalendarBridge.shared.reload()
            NotificationManager.shared.refreshSchedule()
            await SyncEngine.shared.syncIfConfigured()
        }
        .onChange(of: scenePhase) { _, phase in
            // Rebuild on the way in and on the way out, so the schedule reflects
            // anything that changed while the app was closed.
            if phase == .active || phase == .background {
                CalendarBridge.shared.reload()
                NotificationManager.shared.refreshSchedule()
                Task { await SyncEngine.shared.syncIfConfigured() }
            }
        }
    }
}

private extension View {
    /// Lets the Liquid Glass tab bar shrink out of the way while scrolling, on the
    /// systems that have it.
    @ViewBuilder
    func bloomTabBarBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
