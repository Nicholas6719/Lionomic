import Foundation
import Observation

/// View-model for the Chat tab. Holds the in-memory conversation history
/// (not persisted across app launches) and drives every send/receive.
///
/// MContext: the system prompt is rebuilt on every `send()` so it reflects
/// the most recent `CachedQuote` prices and any edits the user has made
/// to their profile / holdings / overrides since the tab was opened. The
/// rebuild is cheap — all reads happen against the SwiftData main context
/// plus one actor hop per distinct symbol for the cached quote peek —
/// and the benefit is a prompt that never drifts from the portfolio UI.
@Observable
@MainActor
final class ChatViewModel {

    // MARK: - Public state

    var messages: [ChatMessage] = []
    var inputText: String = ""
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    /// The most recently built system prompt. Populated on the first
    /// `send()` (or the first explicit `buildSystemPrompt()` call from
    /// tests). Exposed so tests can verify the rendered content without
    /// reaching into a private builder.
    private(set) var systemPrompt: String = ""

    // MARK: - Dependencies

    private let aiService: any AIService
    private let profileRepository: ProfileRepository
    private let portfolioRepository: PortfolioRepository
    private let watchlistRepository: WatchlistRepository
    private let marketDataService: MarketDataService

    // MARK: - Init

    init(
        aiService: any AIService,
        profileRepository: ProfileRepository,
        portfolioRepository: PortfolioRepository,
        watchlistRepository: WatchlistRepository,
        marketDataService: MarketDataService
    ) {
        self.aiService = aiService
        self.profileRepository = profileRepository
        self.portfolioRepository = portfolioRepository
        self.watchlistRepository = watchlistRepository
        self.marketDataService = marketDataService
    }

    // MARK: - Actions

    /// Append the user's current `inputText` (if non-empty) and request an
    /// assistant reply. Clears `inputText` immediately after the user
    /// message is appended. Errors land in `errorMessage`; `isLoading`
    /// returns to `false` on both success and failure paths.
    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let outgoing = ChatMessage(role: .user, content: trimmed)
        messages.append(outgoing)
        inputText = ""
        errorMessage = nil
        isLoading = true

        // MContext: rebuild the system prompt at the head of each send so
        // prices and override state are current. Cheap relative to the
        // actual AI round-trip.
        let prompt = await buildSystemPrompt()
        self.systemPrompt = prompt

        let wireHistory = messages.map { msg -> AIMessage in
            AIMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        defer { isLoading = false }
        do {
            let reply = try await aiService.complete(
                system: prompt,
                messages: wireHistory
            )
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch let error as AIServiceError {
            errorMessage = Self.userFacing(for: error)
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }

    func clearConversation() {
        messages.removeAll()
        errorMessage = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Error messaging

    private static func userFacing(for error: AIServiceError) -> String {
        switch error {
        case .notConfigured:
            return "Add your Anthropic API key in Settings → API Keys to start chatting."
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        }
    }

    // MARK: - System prompt

    /// Build an enriched system prompt from the current SwiftData state.
    /// Exposed (not private) so tests can assert on the rendered prompt
    /// without spinning up an end-to-end send. Safe to call repeatedly;
    /// every call reads fresh.
    func buildSystemPrompt() async -> String {
        let profile: InvestingProfile? = (try? profileRepository.fetchProfile()) ?? nil
        let accounts: [Account] = (try? portfolioRepository.fetchAccounts()) ?? []
        let standard: [WatchlistItem] = (try? watchlistRepository.fetchItems(in: .standard)) ?? []
        let highPriority: [WatchlistItem] = (try? watchlistRepository.fetchItems(in: .highPriorityOpportunity)) ?? []

        // Collect the distinct symbols across holdings and watchlist
        // items (non-NFT only — NFTs don't live in the cached-quote
        // table). Deduplicated via Set to avoid repeated actor hops.
        var symbols: Set<String> = []
        for account in accounts {
            for holding in account.holdings where holding.assetType.usesMarketQuote {
                symbols.insert(holding.symbol)
            }
        }
        for item in standard where item.assetType.usesMarketQuote {
            symbols.insert(item.symbol)
        }
        for item in highPriority where item.assetType.usesMarketQuote {
            symbols.insert(item.symbol)
        }

        // Query the cache for each symbol. `cachedQuote` never triggers
        // a network fetch — it reads whatever is already in SwiftData,
        // which is exactly the right policy for prompt enrichment
        // (we never want to cause network traffic just because the user
        // tapped Send).
        var quotes: [String: Decimal] = [:]
        for symbol in symbols {
            if let quote = await marketDataService.cachedQuote(for: symbol) {
                quotes[symbol] = quote.price
            }
        }

        // Resolve per-account overrides so the prompt can surface any
        // that differ from the global profile.
        var overrides: [(account: Account, effective: EffectiveProfile)] = []
        if let profile {
            for account in accounts {
                let override = profileRepository.override(for: account)
                guard override != nil else { continue }
                let effective = EffectiveProfile.resolve(profile: profile, override: override)
                overrides.append((account, effective))
            }
        }

        return Self.renderSystemPrompt(
            profile: profile,
            accounts: accounts,
            standardWatchlist: standard,
            highPriorityWatchlist: highPriority,
            quotes: quotes,
            overrides: overrides
        )
    }

    /// Pure renderer. Extracted so tests can feed it known data without
    /// touching SwiftData or MarketDataService.
    static func renderSystemPrompt(
        profile: InvestingProfile?,
        accounts: [Account],
        standardWatchlist: [WatchlistItem],
        highPriorityWatchlist: [WatchlistItem],
        quotes: [String: Decimal],
        overrides: [(account: Account, effective: EffectiveProfile)]
    ) -> String {
        var out = """
        You are Lionomic, a private investing guidance assistant. You give thoughtful, evidence-backed guidance. You are not a licensed financial advisor and always note this when giving specific recommendations.
        """

        // ## Portfolio Overview — global investing profile.
        if let profile {
            out += "\n\n## Portfolio Overview"
            out += "\n- Risk tolerance: \(profile.riskTolerance.displayName)"
            out += "\n- Investment horizon: \(profile.horizonPreference.displayName)"
            out += "\n- Caution bias: \(profile.cautionBias.displayName)"
            out += "\n- Concentration sensitivity: \(profile.concentrationSensitivity.displayName)"
            out += "\n- Prefers buying dips: \(profile.preferDipBuying ? "Yes" : "No")"
        }

        // ## Holdings — per-account listing, unchanged from MChat.
        if !accounts.isEmpty {
            out += "\n\n## Holdings"
            for account in accounts {
                out += "\n### \(account.displayName) (\(account.kind.displayName))"
                let sortedHoldings = account.holdings.sorted { $0.symbol < $1.symbol }
                if sortedHoldings.isEmpty {
                    out += "\n- (no holdings in this account)"
                    continue
                }
                for holding in sortedHoldings {
                    var line = "\n- \(holding.symbol) [\(holding.assetType.displayName)]"
                    if let shares = holding.shares {
                        line += " — \(format(decimal: shares)) shares"
                    }
                    if let cost = holding.averageCost {
                        line += " @ avg cost \(MoneyFormatter.string(from: cost))"
                    }
                    if let manual = holding.manualValuation {
                        line += " — manual valuation \(MoneyFormatter.string(from: manual))"
                    }
                    out += line
                }
            }
        }

        // ## Watchlist — unchanged from MChat.
        if !standardWatchlist.isEmpty || !highPriorityWatchlist.isEmpty {
            out += "\n\n## Watchlist"
            for item in standardWatchlist {
                out += "\n- \(item.symbol) [\(item.assetType.displayName)] — standard"
            }
            for item in highPriorityWatchlist {
                out += "\n- \(item.symbol) [\(item.assetType.displayName)] — high-priority"
            }
        }

        // ## Current Market Prices — compact lookup table of cached
        // prices, one line per symbol that has a cached quote. Symbols
        // without a cached quote are omitted rather than shown as zero
        // or stale.
        if !quotes.isEmpty {
            out += "\n\n## Current Market Prices"
            for symbol in quotes.keys.sorted() {
                if let price = quotes[symbol] {
                    out += "\n- \(symbol): \(MoneyFormatter.string(from: price))"
                }
            }
        }

        // ## Account Overrides — only accounts whose EffectiveProfile
        // actually differs from the global profile. Section omitted
        // entirely when empty.
        if !overrides.isEmpty {
            out += "\n\n## Account Overrides"
            for (account, effective) in overrides {
                out += "\n- \(account.displayName) — risk: \(effective.riskTolerance.displayName), horizon: \(effective.horizonPreference.displayName), caution: \(effective.cautionBias.displayName)"
            }
        }

        return out
    }

    private static func format(decimal value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
