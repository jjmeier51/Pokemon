import SwiftUI

struct CollectionView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    @State private var filter = CollectionFilter()
    @State private var showFilters = false
    @State private var selectedCard: Card?

    private var currentSet: CardSet { catalog.selectedSet(id: settings.selectedSetID) }

    private var visibleCards: [Card] {
        filter.apply(to: currentSet.cards, collection: collection, prices: prices)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: max(2, min(4, settings.gridColumns)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.background
                ScrollView {
                    VStack(spacing: 16) {
                        SetSwitcher()
                            .padding(.top, 8)
                        logoBanner
                        header
                        sectionChips
                        statusPicker
                        grid
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("PokeTracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PokeTheme.deepNavy.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: filter.isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(filter.isFiltering ? PokeTheme.yellow : .white)
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .searchable(text: $filter.search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search cards, numbers, artists…")
            .sheet(isPresented: $showFilters) {
                FilterSheet(filter: $filter, rarities: currentSet.rarities, sections: currentSet.sections)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card, siblings: visibleCards)
            }
        }
    }

    // MARK: - Header

    private var logoBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(currentSet.logoAsset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: currentSet.id == "CEL" ? 44 : 64)
                .frame(maxWidth: currentSet.id == "CEL" ? 190 : nil)
                .shadow(color: PokeTheme.gold.opacity(0.45), radius: 12, y: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text("Pokémon TCG")
                    .font(PokeTheme.caption(11))
                    .tracking(1.2)
                    .foregroundStyle(PokeTheme.textSecondary)
                Text(currentSet.shortName)
                    .font(PokeTheme.title(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(currentSet.tagline)
                    .font(PokeTheme.caption(11))
                    .foregroundStyle(PokeTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Image(currentSet.markAsset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
                .opacity(0.9)
        }
        .padding(.top, 2)
    }

    private var scopedCards: [Card] {
        if let section = filter.section { return currentSet.cards(in: section) }
        return currentSet.cards
    }

    private var header: some View {
        let total = scopedCards.count
        let owned = collection.collectedCount(in: scopedCards)
        let progress = total == 0 ? 0 : Double(owned) / Double(total)
        return HStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 10)
                    .frame(width: 84, height: 84)
                VStack(spacing: 0) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(PokeTheme.title(20))
                    Text("done")
                        .font(PokeTheme.caption(10))
                        .foregroundStyle(PokeTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(filter.section?.title ?? "Master Set")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .font(PokeTheme.title(22))
                Text("\(owned) of \(total) cards collected")
                    .font(PokeTheme.body(14))
                    .foregroundStyle(PokeTheme.textSecondary)
                HStack(spacing: 8) {
                    Label("\(total - owned) to go", systemImage: "flag.checkered")
                    if let value = collectedValue {
                        Label(value.usd, systemImage: "dollarsign.circle.fill")
                    }
                }
                .font(PokeTheme.caption(12))
                .foregroundStyle(PokeTheme.yellow)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .panel()
        .padding(.top, 8)
    }

    private var collectedValue: Double? {
        let owned = scopedCards.filter { collection.isCollected($0) }
        let values = owned.compactMap { prices.value(of: $0, grading: collection.entry(for: $0)?.grading) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    // MARK: - Chips and pickers

    private var sectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", image: "square.grid.2x2.fill", section: nil)
                ForEach(currentSet.sections) { section in
                    chip(title: section.shortTitle, image: section.systemImage, section: section)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        .frame(maxWidth: .infinity)
    }

    private func chip(title: String, image: String, section: CardSection?) -> some View {
        Button {
            Haptics.selection(enabled: settings.hapticsEnabled)
            withAnimation(.snappy) { filter.section = section }
        } label: {
            SectionChip(title: title, systemImage: image, selected: filter.section == section)
        }
        .buttonStyle(.plain)
    }

    private var statusPicker: some View {
        Picker("Show", selection: $filter.collected) {
            ForEach(CollectedFilter.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $filter.sort) {
                ForEach(SortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
            Toggle(isOn: $filter.ascending) {
                Label(filter.ascending ? "Ascending" : "Descending", systemImage: filter.ascending ? "arrow.up" : "arrow.down")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("Sort")
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        let cards = visibleCards
        if cards.isEmpty {
            ContentUnavailableView {
                Label("No cards here", systemImage: "rectangle.on.rectangle.slash")
            } description: {
                Text(filter.search.isEmpty ? "Try a different filter." : "Nothing matches “\(filter.search)”.")
            }
            .foregroundStyle(PokeTheme.textSecondary)
            .padding(.top, 40)
        } else {
            HStack {
                Text("\(cards.count) cards")
                    .font(PokeTheme.caption(12))
                    .foregroundStyle(PokeTheme.textTertiary)
                Spacer()
                if filter.isFiltering {
                    Button("Clear filters") {
                        withAnimation { filter.collected = .all; filter.rarities = [] }
                    }
                    .font(PokeTheme.caption(12))
                    .foregroundStyle(PokeTheme.yellow)
                }
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(cards) { card in
                    CardGridCell(card: card) {
                        selectedCard = card
                    }
                    .id(card.id)
                }
            }
            .padding(.horizontal, 2)
            .animation(.snappy(duration: 0.3), value: cards.map(\.id))
        }
    }
}
