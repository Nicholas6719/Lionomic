import Foundation

enum AssetType: String, Codable, CaseIterable, Hashable, Sendable {
    case stock
    case etf
    case indexFund = "index_fund"
    case mutualFund = "mutual_fund"
    case nft

    var usesMarketQuote: Bool {
        self != .nft
    }
}
