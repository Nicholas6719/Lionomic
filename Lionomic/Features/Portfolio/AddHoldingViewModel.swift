import Foundation
import Observation

@Observable
@MainActor
final class AddHoldingViewModel {

    var draft: DraftHolding
    var showingReview = false
    var errorMessage: String?

    let account: Account

    init(account: Account) {
        self.account = account
        self.draft   = DraftHolding(accountID: account.id)
    }

    var isNFT: Bool { draft.assetType == .nft }

    var canRequestReview: Bool {
        let symbolOK = !draft.symbol.trimmingCharacters(in: .whitespaces).isEmpty
        if isNFT {
            return symbolOK && (draft.manualValuation ?? .zero) > .zero
        } else {
            guard let shares = draft.shares, let cost = draft.averageCost else { return false }
            return symbolOK && shares > .zero && cost > .zero
        }
    }
}
