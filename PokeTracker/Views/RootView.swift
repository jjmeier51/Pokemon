import SwiftUI

struct RootView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

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
            // Warm the price cache for anything the user has collected so the Progress tab has numbers.
            guard settings.autoRefreshPrices else { return }
            let owned = catalog.cards.filter { collection.isCollected($0) }
            await prices.refreshAll(owned, settings: settings, onlyStale: true)
        }
    }
}
