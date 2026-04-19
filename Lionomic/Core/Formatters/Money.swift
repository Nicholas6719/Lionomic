import Foundation

enum MoneyFormatter {
    static let defaultCurrencyCode = "USD"

    /// Standard currency formatting. Negative values use the locale's
    /// default negative style; positive values have no sign.
    static func string(
        from value: Decimal,
        currencyCode: String = defaultCurrencyCode
    ) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    /// Signed currency formatting. Positive values are prefixed with `+`,
    /// zero is rendered as the plain currency value, negatives use the
    /// locale's default negative style (typically `-$1.23`).
    ///
    /// Use for change amounts (price delta, P/L, etc.) where sign is meaningful.
    static func signedString(
        from value: Decimal,
        currencyCode: String = defaultCurrencyCode
    ) -> String {
        let base = value.formatted(.currency(code: currencyCode))
        if value > 0 {
            return "+" + base
        }
        return base
    }
}
