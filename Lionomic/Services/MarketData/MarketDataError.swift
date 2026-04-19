import Foundation

enum MarketDataError: Error, Equatable, LocalizedError {
    case missingAPIKey(provider: String)
    case networkError(providerName: String, message: String)
    case decodingError(providerName: String)
    case rateLimitExceeded(provider: String)
    case allProvidersFailed
    case symbolNotFound(symbol: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider): API key not configured. Add one in Settings → API Keys."
        case .networkError(let name, let message):
            return "\(name): network error (\(message))."
        case .decodingError(let name):
            return "\(name): could not decode response."
        case .rateLimitExceeded(let provider):
            return "\(provider): rate limit exceeded."
        case .allProvidersFailed:
            return "All market data providers failed."
        case .symbolNotFound(let symbol):
            return "Symbol \"\(symbol)\" not found."
        }
    }

    /// Wraps an arbitrary error in .networkError so MarketDataError stays Equatable.
    static func network(_ providerName: String, _ underlying: Error) -> MarketDataError {
        .networkError(providerName: providerName, message: String(describing: underlying))
    }
}
