import SwiftUI

/// Rectangular uppercase label with the color of a type. Also used for weaknesses ("FIRE ×2").
public struct TypeChip: View {
    private let label: String
    private let tint: TypeTint

    public init(_ label: String, tint: TypeTint) {
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        Text(label.uppercased())
            .font(.mono(10))
            .foregroundStyle(tint.onColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(tint.color, in: .rect(cornerRadius: Radius.sm))
            .accessibilityLabel(label)
    }
}

#Preview("Type chips") {
    FlowPreview(items: TypeTint.allCases) { TypeChip($0.rawValue, tint: $0) }
}
