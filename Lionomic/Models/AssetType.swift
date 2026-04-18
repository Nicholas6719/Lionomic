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

    var displayName: String {
        switch self {
        case .stock:      return "Stock"
        case .etf:        return "ETF"
        case .indexFund:  return "Index Fund"
        case .mutualFund: return "Mutual Fund"
        case .nft:        return "NFT"
        }
    }
}
