import SwiftUI

struct FilterSheet: View {
    @Binding var filter: CollectionFilter
    let rarities: [Rarity]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.background
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        group("Collection status") {
                            Picker("Status", selection: $filter.collected) {
                                ForEach(CollectedFilter.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }

                        group("Rarity") {
                            VStack(spacing: 8) {
                                ForEach(rarities) { rarity in
                                    rarityRow(rarity)
                                }
                            }
                        }

                        group("Section") {
                            VStack(spacing: 8) {
                                sectionRow(nil, title: "Everything")
                                ForEach(CardSection.allCases) { section in
                                    sectionRow(section, title: section.title)
                                }
                            }
                        }

                        group("Sort") {
                            Picker("Sort", selection: $filter.sort) {
                                ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(PokeTheme.yellow)
                            Toggle("Ascending", isOn: $filter.ascending)
                                .tint(PokeTheme.gold)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        filter.collected = .all
                        filter.rarities = []
                        filter.section = nil
                        filter.sort = .number
                        filter.ascending = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(PokeTheme.caption(11))
                .tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            content()
        }
    }

    private func rarityRow(_ rarity: Rarity) -> some View {
        let selected = filter.rarities.contains(rarity)
        return Button {
            if selected { filter.rarities.remove(rarity) } else { filter.rarities.insert(rarity) }
        } label: {
            HStack {
                RarityBadge(rarity: rarity)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? PokeTheme.yellow : PokeTheme.textTertiary)
                    .font(.system(size: 20))
            }
            .padding(12)
            .background(Color.white.opacity(selected ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sectionRow(_ section: CardSection?, title: String) -> some View {
        let selected = filter.section == section
        return Button {
            filter.section = section
        } label: {
            HStack {
                Image(systemName: section?.systemImage ?? "square.grid.2x2.fill")
                    .foregroundStyle(PokeTheme.yellow)
                    .frame(width: 22)
                Text(title).font(PokeTheme.body(15))
                if let section {
                    Text(section.subtitle).font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textTertiary)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? PokeTheme.yellow : PokeTheme.textTertiary)
                    .font(.system(size: 20))
            }
            .padding(12)
            .background(Color.white.opacity(selected ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
