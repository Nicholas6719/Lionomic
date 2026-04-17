import Foundation

enum MoneyFormatter {
    static let defaultCurrencyCode = "USD"

    static func string(
        from value: Decimal,
        currencyCode: String = defaultCurrencyCode
    ) -> String {
        value.formatted(.currency(code: currencyCode))
    }
}
