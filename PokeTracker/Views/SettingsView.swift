import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    @State private var confirmReset = false
    @State private var showImporter = false
    @State private var exportDocument: CollectionDocument?
    @State private var importMessage: String?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    SecureField("API key", text: $settings.cardLadderAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Base URL", text: $settings.cardLadderBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.footnote)
                    if settings.cardLadderBaseURL != AppSettings.defaultCardLadderBaseURL {
                        Button("Use default endpoint") { settings.cardLadderBaseURL = AppSettings.defaultCardLadderBaseURL }
                    }
                } header: {
                    Text("Card Ladder")
                } footer: {
                    Text("Card Ladder has no public API, so PokeTracker reads CL Values and sales through the Parse.bot Card Ladder API wrapper. Create a free key at parse.bot and paste it here. Any endpoint that mirrors the same routes (search_cards, get_card_value, get_card_sales) also works.")
                }

                Section("Prices") {
                    Toggle("Also refresh a card's prices when you open it", isOn: $settings.autoRefreshPrices)
                    Button {
                        Task { await prices.refreshAll(catalog.cards, settings: settings, onlyStale: false) }
                    } label: {
                        HStack {
                            Text("Refresh every card now")
                            Spacer()
                            if let progress = prices.bulkProgress {
                                Text("\(progress.done)/\(progress.total)").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                    .disabled(prices.bulkProgress != nil)
                    if let last = prices.lastUpdated {
                        LabeledContent("Last updated") { Text(last, style: .relative) + Text(" ago") }
                    }
                    Button("Clear price cache", role: .destructive) { prices.clearCache() }
                }

                Section("Display") {
                    Stepper("Grid columns: \(settings.gridColumns)", value: $settings.gridColumns, in: 2...4)
                    Toggle("Grey out cards you've collected", isOn: $settings.dimCollectedCards)
                    Toggle("Glitter borders on rare cards", isOn: $settings.sparkleEffects)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Button("Clear downloaded artwork cache") { ImageStore.shared.clearDiskCache() }
                }

                Section("Backup") {
                    Button {
                        if let data = try? collection.exportData() { exportDocument = CollectionDocument(data: data) }
                    } label: {
                        Label("Export collection…", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import collection…", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Reset collection", systemImage: "trash")
                    }
                }

                Section("About") {
                    LabeledContent("Set", value: "\(catalog.setName) (\(catalog.setCode))")
                    LabeledContent("Cards tracked", value: "\(catalog.cards.count)")
                    if let release = catalog.releaseDate {
                        LabeledContent("Released", value: release.formatted(date: .long, time: .omitted))
                    }
                    Text("Card list and rarities follow the official Pokémon TCG: 30th Celebration checklist, plus the three unlisted RGB Mew secret rares. Market data from TCGplayer and Card Ladder. PokeTracker is a fan-made collection tracker and is not affiliated with The Pokémon Company, Nintendo, Creatures or GAME FREAK.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background { PokeTheme.background }
            .navigationTitle("Settings")
            .toolbarBackground(PokeTheme.deepNavy.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog("Remove every card from your collection?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset collection", role: .destructive) { collection.reset() }
            }
            .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                          document: exportDocument, contentType: .json, defaultFilename: "PokeTracker-30th-Celebration") { _ in
                exportDocument = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        try collection.importData(data, merge: true)
                        importMessage = "Imported \(collection.collectedIDs.count) collected cards."
                    } catch {
                        importMessage = "Couldn't import: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    importMessage = error.localizedDescription
                }
            }
            .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }
}

struct CollectionDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
