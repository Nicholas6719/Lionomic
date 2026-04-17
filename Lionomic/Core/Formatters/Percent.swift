import Foundation

enum PercentFormatter {
    /// `ratio` is a decimal fraction (e.g. `0.015` renders as `1.50%`).
    static func string(from ratio: Decimal, fractionDigits: Int = 2) -> String {
        ratio.formatted(.percent.precision(.fractionLength(fractionDigits)))
    }
}
