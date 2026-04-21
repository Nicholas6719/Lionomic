import Foundation
import Observation

/// View-model for the Chat tab. Holds the in-memory conversation history
/// (not persisted across app launches) and drives every send/receive.
///
/// A system prompt is built once at init from the user's investing
/// profile, holdings, and watchlist. The prompt does not update during
/// the session — reopening the Chat tab rebuilds it, but sending new
/// messages does not.
@Observable
@MainActor
final class ChatViewModel {

    // MARK: - Public state

    var messages: [ChatMessage] = []
    var inputText: String = ""
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    /// Exposed for tests so the prompt contents can be verified without
    /// reaching into the private builder. Not read by the view.
    let systemPrompt: String

    // MARK: - Dependencies

    private let aiService: any AIService

    // MARK: - Init

    init(
        aiService: any AIService,
        profileRepository: ProfileRepository,
        portfolioRepository: PortfolioRepository,
        watchlistRepository: WatchlistRepository
    ) {
        self.aiService = aiService

        let profile: InvestingProfile? = (try? profileRepository.fetchProfile()) ?? nil
        let accounts: [Account] = (try? portfolioRepository.fetchAccounts()) ?? []
        let standard: [WatchlistItem] = (try? watchlistRepository.fetchItems(in: .standard)) ?? []
        let highPriority: [WatchlistItem] = (try? watchlistRepository.fetchItems(in: .highPriorityOpportunity)) ?? []

        self.systemPrompt = Self.buildSystemPrompt(
            profile: profile,
            accounts: accounts,
            standardWatchlist: standard,
            highPriorityWatchlist: highPriority
        )
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

        let wireHistory = messages.map { msg -> AIMessage in
            AIMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        defer { isLoading = false }
        do {
            let reply = try await aiService.complete(
                system: systemPrompt,
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

    private static func buildSystemPrompt(
        profile: InvestingProfile?,
        accounts: [Account],
        standardWatchlist: [WatchlistItem],
        highPriorityWatchlist: [WatchlistItem]
    ) -> String {
        var out = """
        You are Lionomic, a private investing guidance assistant. You give thoughtful, evidence-backed guidance. You are not a licensed financial advisor and always note this when giving specific recommendations.
        """

        if let profile {
            out += "\n\n## User investing profile"
            out += "\n- Risk tolerance: \(profile.riskTolerance.displayName)"
            out += "\n- Investment horizon: \(profile.horizonPreference.displayName)"
            out += "\n- Caution bias: \(profile.cautionBias.displayName)"
            out += "\n- Concentration sensitivity: \(profile.concentrationSensitivity.displayName)"
            out += "\n- Prefers buying dips: \(profile.preferDipBuying ? "Yes" : "No")"
        }

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

        if !standardWatchlist.isEmpty || !highPriorityWatchlist.isEmpty {
            out += "\n\n## Watchlist"
            for item in standardWatchlist {
                out += "\n- \(item.symbol) [\(item.assetType.displayName)] — standard"
            }
            for item in highPriorityWatchlist {
                out += "\n- \(item.symbol) [\(item.assetType.displayName)] — high-priority"
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
