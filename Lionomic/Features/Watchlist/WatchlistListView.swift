import SwiftUI

/// Shows both watchlists (Standard + High-Priority Opportunity) as sections,
/// each with live quote data per item. A + button adds a new symbol to the
/// current watchlist; swipe-to-delete with confirmation removes an item.
///
/// M5 scope: list, add, remove. Detail view and edit flow come in later milestones.
struct WatchlistListView: View {

    @Environment(AppEnvironment.self) private var env

    // Section state
    @State private var itemsByKind: [WatchlistKind: [WatchlistItem]] = [:]

    // Live quotes keyed by symbol
    @State private var quotes: [String: QuoteResult] = [:]
    @State private var quoteErrors: Set<String> = []

    // UI flags
    @State private var addingTo: WatchlistKind?
    @State private var pendingDelete: WatchlistItem?

    var body: some View {
        List {
            ForEach(WatchlistKind.allCases, id: \.self) { kind in
                Section {
                    let items = itemsByKind[kind] ?? []
                    if items.isEmpty {
                        HStack {
                            Image(systemName: emptyIcon(for: kind))
                                .foregroundStyle(.tertiary)
                            Text("No symbols yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") { addingTo = kind }
                                .font(.caption.weight(.medium))
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(items) { item in
                            WatchlistItemRow(
                                item: item,
                                quote: quotes[item.symbol],
                                hadError: quoteErrors.contains(item.symbol)
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = item
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(kind.displayName)
                        Spacer()
                        Button {
                            addingTo = kind
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .accessibilityLabel("Add to \(kind.displayName)")
                    }
                }
            }
        }
        .navigationTitle("Watchlists")
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .sheet(item: $addingTo, onDismiss: { Task { await reload() } }) { kind in
            AddWatchlistItemView(watchlistKind: kind)
        }
        .confirmationDialog(
            "Remove from watchlist?",
            isPresented: .init(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Remove \(item.symbol)", role: .destructive) {
                confirmDelete(item)
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { item in
            Text("\(item.symbol) will be removed from the \(item.watchlist?.kind.displayName ?? "") watchlist.")
        }
    }

    // MARK: - Loading

    private func reload() async {
        loadItems()
        await loadQuotes()
    }

    private func loadItems() {
        for kind in WatchlistKind.allCases {
            let items = (try? env.watchlistRepository.fetchItems(in: kind)) ?? []
            itemsByKind[kind] = items
        }
    }

    private func loadQuotes() async {
        let symbols: [String] = WatchlistKind.allCases.flatMap { kind in
            (itemsByKind[kind] ?? [])
                .filter { $0.assetType.usesMarketQuote }
                .map(\.symbol)
        }
        let unique = Array(Set(symbols))
        for symbol in unique {
            do {
                let quote = try await env.marketDataService.fetchQuote(symbol: symbol)
                quotes[symbol] = quote
                quoteErrors.remove(symbol)
            } catch {
                quoteErrors.insert(symbol)
            }
        }
    }

    // MARK: - Delete

    private func confirmDelete(_ item: WatchlistItem) {
        do {
            try env.watchlistRepository.commitDelete(item)
            pendingDelete = nil
            loadItems()
        } catch {
            pendingDelete = nil
        }
    }

    private func emptyIcon(for kind: WatchlistKind) -> String {
        switch kind {
        case .standard:                return "list.bullet.rectangle"
        case .highPriorityOpportunity: return "star"
        }
    }
}

// Allow `WatchlistKind` to be used with `.sheet(item:)`.
extension WatchlistKind: Identifiable {
    public var id: Self { self }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    // Seed so the preview has the two default watchlists to render.
    try? env.watchlistRepository.seedDefaultsIfNeeded()
    return NavigationStack {
        WatchlistListView()
            .environment(env)
    }
}
