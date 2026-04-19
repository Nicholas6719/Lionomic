import Foundation

/// Primary provider for live quotes.
///
/// Endpoint: `https://api.twelvedata.com/quote?symbol=…&apikey=…`
/// Success response (abbreviated):
///   { "symbol":"AAPL", "close":"187.45", "change":"1.23",
///     "percent_change":"0.66", "currency":"USD", ... }
/// Error response:
///   { "code": 401, "message": "...", "status": "error" }
///
/// All numeric values come back as JSON strings. `percent_change` is a whole-number
/// percent (e.g. "0.66" means 0.66%), so we divide by 100 to store it as a ratio
/// in `QuoteResult.changePercent` — matching `FinnhubProvider`.
struct TwelveDataProvider: MarketDataProvider {

    nonisolated let name = "Twelve Data"
    let keychain: KeychainService
    let session: URLSession

    nonisolated init(keychain: KeychainService, session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    nonisolated func fetchQuote(symbol: String) async throws -> QuoteResult {
        guard
            let key = keychain.load(identifier: KeychainService.twelveDataApiKeyIdentifier),
            !key.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw MarketDataError.missingAPIKey(provider: name)
        }

        var components = URLComponents(string: "https://api.twelvedata.com/quote")!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: key),
        ]
        guard let url = components.url else {
            throw MarketDataError.decodingError(providerName: name)
        }

        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw MarketDataError.network(name, error)
        }

        // Error envelope (e.g. bad symbol, rate limit) — decode first, fall through on failure.
        if let errorPayload = try? JSONDecoder().decode(TwelveDataErrorPayload.self, from: data),
           errorPayload.status == "error" {
            if errorPayload.code == 429 {
                throw MarketDataError.rateLimitExceeded(provider: name)
            }
            if errorPayload.code == 400 || errorPayload.code == 404 {
                throw MarketDataError.symbolNotFound(symbol: symbol)
            }
            throw MarketDataError.networkError(providerName: name, message: errorPayload.message ?? "unknown")
        }

        guard let payload = try? JSONDecoder().decode(TwelveDataQuotePayload.self, from: data) else {
            throw MarketDataError.decodingError(providerName: name)
        }
        guard
            let price = Decimal(string: payload.close),
            let change = Decimal(string: payload.change ?? "0"),
            let percentWhole = Decimal(string: payload.percent_change ?? "0")
        else {
            throw MarketDataError.decodingError(providerName: name)
        }

        return QuoteResult(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: percentWhole / 100,  // Twelve Data returns percent in whole-number form; store ratio.
            currency: payload.currency ?? "USD",
            fetchedAt: Date(),
            providerName: name
        )
    }
}

// MARK: - JSON (file-scope; nonisolated)

nonisolated private struct TwelveDataQuotePayload: Decodable, Sendable {
    let close: String
    let change: String?
    let percent_change: String?
    let currency: String?
}

nonisolated private struct TwelveDataErrorPayload: Decodable, Sendable {
    let code: Int?
    let message: String?
    let status: String?
}
