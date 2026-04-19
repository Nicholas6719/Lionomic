import Foundation

/// Primary provider for live quotes.
///
/// Endpoint: `https://api.twelvedata.com/price?symbol=…&apikey=…`
/// Response (success): `{"price": "123.45"}`
/// Response (error):   `{"code": 401, "message": "...", "status": "error"}`
///
/// The free `/price` endpoint does not return change or percent-change, so those
/// fields are reported as zero. Upgrading to `/quote` would enrich this later.
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

        var components = URLComponents(string: "https://api.twelvedata.com/price")!
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

        guard let payload = try? JSONDecoder().decode(TwelveDataPayload.self, from: data) else {
            throw MarketDataError.decodingError(providerName: name)
        }
        guard let price = Decimal(string: payload.price) else {
            throw MarketDataError.decodingError(providerName: name)
        }

        return QuoteResult(
            symbol: symbol,
            price: price,
            change: 0,
            changePercent: 0,
            currency: "USD",
            fetchedAt: Date(),
            providerName: name
        )
    }
}

// MARK: - JSON (file-scope; nonisolated)

nonisolated private struct TwelveDataPayload: Decodable, Sendable {
    let price: String
}

nonisolated private struct TwelveDataErrorPayload: Decodable, Sendable {
    let code: Int?
    let message: String?
    let status: String?
}
