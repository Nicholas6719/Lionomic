import Foundation

/// Fallback provider.
///
/// Endpoint: `https://finnhub.io/api/v1/quote?symbol=…&token=…`
/// Response: `{"c": current, "d": change, "dp": percentChange, "h": high, "l": low, "o": open, "pc": prevClose, "t": timestamp}`
///
/// Decodes only `c`, `d`, `dp` — the fields Lionomic needs.
/// An "empty" response (all zeros + `t == 0`) signals an unknown symbol at Finnhub.
struct FinnhubProvider: MarketDataProvider {

    nonisolated let name = "Finnhub"
    let keychain: KeychainService
    let session: URLSession

    nonisolated init(keychain: KeychainService, session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    nonisolated func fetchQuote(symbol: String) async throws -> QuoteResult {
        guard
            let key = keychain.load(identifier: KeychainService.finnhubApiKeyIdentifier),
            !key.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw MarketDataError.missingAPIKey(provider: name)
        }

        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "token", value: key),
        ]
        guard let url = components.url else {
            throw MarketDataError.decodingError(providerName: name)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw MarketDataError.network(name, error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw MarketDataError.rateLimitExceeded(provider: name)
            }
            if http.statusCode == 404 {
                throw MarketDataError.symbolNotFound(symbol: symbol)
            }
            if !(200..<300).contains(http.statusCode) {
                throw MarketDataError.networkError(providerName: name, message: "HTTP \(http.statusCode)")
            }
        }

        guard let payload = try? JSONDecoder().decode(FinnhubPayload.self, from: data) else {
            throw MarketDataError.decodingError(providerName: name)
        }

        // Empty/unknown-symbol sentinel: Finnhub returns zeros + t == 0 for unknown symbols.
        if payload.c == 0, payload.t == 0 {
            throw MarketDataError.symbolNotFound(symbol: symbol)
        }

        return QuoteResult(
            symbol: symbol,
            price: Self.decimal(payload.c),
            change: Self.decimal(payload.d ?? 0),
            changePercent: Self.decimal(payload.dp ?? 0) / 100,  // Finnhub returns 1.5 for 1.5%; QuoteResult stores ratios.
            currency: "USD",
            fetchedAt: Date(),
            providerName: name
        )
    }

    nonisolated private static func decimal(_ value: Double) -> Decimal {
        // Route through String to avoid binary floating-point imprecision.
        Decimal(string: String(value)) ?? Decimal(value)
    }

}

// MARK: - JSON (file-scope; nonisolated)

nonisolated private struct FinnhubPayload: Decodable, Sendable {
    let c: Double        // current price
    let d: Double?       // change
    let dp: Double?      // percent change
    let t: Int           // unix timestamp; 0 indicates empty/unknown symbol response
}
