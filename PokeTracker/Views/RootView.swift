import SwiftUI

struct RootView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastFullRefresh: Date?

    var body: some View {
        TabView {
            CollectionView()
                .tabItem { Label("Collection", systemImage: "rectangle.stack.fill") }
            StatsView()
                .tabItem { Label("Progress", systemImage: "chart.pie.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .toolbarBackground(PokeTheme.deepNavy.opacity(0.95), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            await refreshEverything()
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-pull prices when the app is brought back to the foreground (skip if we just did).
            guard phase == .active, let last = lastFullRefresh, Date().timeIntervalSince(last) > 120 else { return }
            Task { await refreshEverything() }
        }
    }

    private func refreshEverything() async {
        guard prices.bulkProgress == nil else { return }
        lastFullRefresh = Date()
        await prices.refreshAll(catalog.cards, settings: settings, onlyStale: false)
        lastFullRefresh = Date()
    }
}
