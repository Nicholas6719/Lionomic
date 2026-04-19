import Foundation

enum PercentFormatter {
    /// `ratio` is a decimal fraction (e.g. `0.015` renders as `1.50%`).
    static func string(from ratio: Decimal, fractionDigits: Int = 2) -> String {
        ratio.formatted(.percent.precision(.fractionLength(fractionDigits))
            .sign(strategy: .automatic))
    }

    /// Signed percent. Positive ratios render with a leading `+` (`+1.50%`);
    /// negatives follow the locale's negative style (typically `-0.55%`).
    ///
    /// Use for change-percent values where sign carries meaning.
    static func signedString(from ratio: Decimal, fractionDigits: Int = 2) -> String {
        let base = ratio.formatted(.percent.precision(.fractionLength(fractionDigits)))
        if ratio > 0 {
            return "+" + base
        }
        return base
    }
}
