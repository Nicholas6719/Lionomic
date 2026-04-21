import SwiftUI

/// Single source of truth for visual tokens. Introduced in MUI.
enum DesignSystem {
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
        static let row: CGFloat = 10
        static let badge: CGFloat = 6
    }
}

// `Color.lionomicAccent` is auto-generated from the `LionomicAccent`
// color set in Assets.xcassets by Xcode's GeneratedAssetSymbols. We do
// not redeclare it here to avoid a redeclaration error.
extension Color {
    static let gainGreen = Color(.systemGreen)
    static let lossRed = Color(.systemRed)
}
