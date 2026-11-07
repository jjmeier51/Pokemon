import SwiftUI

/// Page-by-page view of where every card goes in a 9-pocket binder, in ETB booklet order.
struct BinderView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    @State private var pageIndex = 0
    @State private var search = ""
    @State private var highlightedCardID: String?
    @State private var selectedCard: Card?
    @State private var searchMiss = false

    private var currentSet: CardSet { catalog.selectedSet(id: settings.selectedSetID) }
    private var options: BinderOptions {
        BinderOptions(includeExtras: settings.binderIncludeExtras, sectionsStartNewPage: settings.binderSectionsStartNewPage)
    }
    private var pages: [BinderPage] { BinderLayout.pages(for: currentSet, options: options) }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ZStack {
                PokeTheme.background
                let pages = self.pages
                VStack(spacing: 12) {
                    SetSwitcher()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    if pages.isEmpty {
                        ContentUnavailableView("No pages", systemImage: "book.closed")
                            .foregroundStyle(PokeTheme.textSecondary)
                    } else {
                        header(pages)
                        TabView(selection: $pageIndex) {
                            ForEach(pages) { page in
                                BinderPageView(page: page, totalPages: pages.count, highlightedCardID: highlightedCardID) { card in
                                    selectedCard = card
                                }
                                .padding(.horizontal, 16)
                                .tag(page.index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        pageStrip(pages)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Binder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PokeTheme.deepNavy.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        jumpToFirstMissing()
                    } label: {
                        Image(systemName: "flag.checkered")
                    }
                    .accessibilityLabel("Jump to first empty pocket")
                    Menu {
                        Toggle("Start each section on a new page", isOn: $settings.binderSectionsStartNewPage)
                        Toggle("Include RGB Mew and promos", isOn: $settings.binderIncludeExtras)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Find a card's pocket")
            .onSubmit(of: .search) { jump(to: search) }
            .onChange(of: search) { _, query in
                if query.count >= 3 { jump(to: query) }
            }
            .onChange(of: pages.count) { _, count in
                if pageIndex >= count { pageIndex = max(0, count - 1) }
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card, siblings: currentSet.cards)
            }
            .alert("No match", isPresented: $searchMiss) {
                Button("OK") {}
            } message: {
                Text("No card in \(currentSet.shortName) matches “\(search)”.")
            }
        }
    }

    // MARK: - Header

    private func header(_ pages: [BinderPage]) -> some View {
        let page = pages[min(pageIndex, pages.count - 1)]
        let filled = page.cards.filter { collection.isCollected($0) }.count
        let value = page.cards.filter { collection.isCollected($0) }
            .compactMap { prices.value(of: $0, grading: collection.entry(for: $0)?.grading) }
            .reduce(0, +)
        let totalFilled = currentSet.cards.filter { card in pages.contains { $0.cards.contains(card) } && collection.isCollected(card) }.count
        let totalSlots = pages.reduce(0) { $0 + $1.cards.count }
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(PokeTheme.title(18))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Page \(page.number) of \(pages.count)")
                        .font(PokeTheme.caption(11))
                        .foregroundStyle(PokeTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(filled)/\(page.cards.count) filled")
                        .font(PokeTheme.headline(14))
                        .foregroundStyle(filled == page.cards.count && !page.cards.isEmpty ? Color(hex: 0x2ED573) : PokeTheme.yellow)
                    if value > 0 {
                        Text("Page value \(value.usd)")
                            .font(PokeTheme.caption(11))
                            .foregroundStyle(PokeTheme.textSecondary)
                    }
                }
            }
            ProgressBar(progress: totalSlots == 0 ? 0 : Double(totalFilled) / Double(totalSlots), tint: PokeTheme.gold, height: 5)
            HStack {
                Text("\(totalFilled) of \(totalSlots) pockets filled")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                Spacer()
                Text("Long-press a pocket to mark it collected")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Page strip

    private func pageStrip(_ pages: [BinderPage]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pages) { page in
                        Button {
                            Haptics.selection(enabled: settings.hapticsEnabled)
                            withAnimation(.snappy) { pageIndex = page.index }
                        } label: {
                            pageThumb(page, selected: page.index == pageIndex)
                        }
                        .buttonStyle(.plain)
                        .id(page.index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity)
            .onChange(of: pageIndex) { _, index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(pageIndex, anchor: .center) }
        }
        .padding(.bottom, 4)
    }

    private func pageThumb(_ page: BinderPage, selected: Bool) -> some View {
        let grid = Array(repeating: GridItem(.fixed(6), spacing: 2), count: 3)
        return VStack(spacing: 3) {
            LazyVGrid(columns: grid, spacing: 2) {
                ForEach(Array(page.slots.enumerated()), id: \.offset) { _, card in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(card == nil ? Color.white.opacity(0.08) : (collection.isCollected(card!) ? PokeTheme.yellow : Color.white.opacity(0.3)))
                        .frame(width: 6, height: 8)
                }
            }
            Text("\(page.number)")
                .font(PokeTheme.mono(9))
                .foregroundStyle(selected ? PokeTheme.yellow : PokeTheme.textTertiary)
        }
        .padding(6)
        .background(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(selected ? PokeTheme.yellow : Color.clear, lineWidth: 1.5))
    }

    // MARK: - Navigation helpers

    private func jump(to query: String) {
        let folded = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !folded.isEmpty else { return }
        let pages = self.pages
        let candidates = pages.flatMap(\.cards)
        let match = candidates.first { $0.displayNumber.lowercased() == folded || $0.number.lowercased() == folded }
            ?? candidates.first { $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).hasPrefix(folded) }
            ?? candidates.first { $0.searchableText.contains(folded) }
        guard let match, let position = BinderLayout.position(of: match, in: pages) else {
            if query.count >= 3 { searchMiss = true }
            return
        }
        withAnimation(.snappy) { pageIndex = position.page - 1 }
        highlight(match)
    }

    private func jumpToFirstMissing() {
        let pages = self.pages
        guard let page = pages.first(where: { $0.cards.contains { !collection.isCollected($0) } }),
              let card = page.cards.first(where: { !collection.isCollected($0) }) else {
            Haptics.success(enabled: settings.hapticsEnabled)
            return
        }
        Haptics.impact(.light, enabled: settings.hapticsEnabled)
        withAnimation(.snappy) { pageIndex = page.index }
        highlight(card)
    }

    private func highlight(_ card: Card) {
        highlightedCardID = card.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if highlightedCardID == card.id { withAnimation { highlightedCardID = nil } }
        }
    }
}
