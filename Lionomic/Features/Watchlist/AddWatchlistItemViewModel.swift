import Foundation
import Observation

/// Drives `AddWatchlistItemView`.
///
/// Holds a `DraftWatchlistItem`, a review-sheet flag, and an error message.
/// Enforces:
///   - non-empty symbol before `canRequestReview`
///   - `targetBuyBelow` is only meaningful for non-NFT assets (hidden for NFT)
@Observable
@MainActor
final class AddWatchlistItemViewModel {

    var draft: DraftWatchlistItem
    var showingReview = false
    var errorMessage: String?

    let watchlistKind: WatchlistKind

    init(watchlistKind: WatchlistKind) {
        self.watchlistKind = watchlistKind
        self.draft = DraftWatchlistItem(
            watchlistKind: watchlistKind,
            symbol: "",
            assetType: .stock
        )
    }

    var isNFT: Bool { draft.assetType == .nft }

    var canRequestReview: Bool {
        !draft.symbol.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// If the user switches to NFT, clear any price target they set —
    /// targets don't apply to manual-valuation assets.
    func assetTypeChanged(to newType: AssetType) {
        draft.assetType = newType
        if newType == .nft {
            draft.targetBuyBelow = nil
        }
    }
}
