import SwiftUI

/// Shared confidence indicator: 5 pips where the filled count is
/// `Int(confidence * 5)` clamped to `0...5`.
struct ConfidencePipsView: View {
    let confidence: Double

    private var filled: Int {
        max(0, min(5, Int(confidence * 5)))
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < filled ? "circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(index < filled ? Color.lionomicAccent : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(filled) of 5")
    }
}
