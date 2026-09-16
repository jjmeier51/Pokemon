import SwiftUI

@main
struct PokeTrackerApp: App {
    @State private var catalog = CardCatalog.load()
    @State private var collection = CollectionStore()
    @State private var prices = PriceCenter()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(collection)
                .environment(prices)
                .environment(settings)
                .preferredColorScheme(.dark)
                .tint(PokeTheme.yellow)
        }
    }
}
