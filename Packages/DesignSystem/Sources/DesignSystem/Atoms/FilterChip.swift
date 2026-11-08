import SwiftUI

/// Selectable filter. The selected one uses the yellow accent; the others show a bar with their type color.
public struct FilterChip: View {
    private let label: String
    private let tint: Color?
    private let isSelected: Bool
    private let action: () -> Void

    /// - Parameter tint: Color of the side bar. Pass `nil` for filters without a type, such as "All".
    public init(_ label: String, tint: Color? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let tint, !isSelected {
                    Rectangle().fill(tint).frame(width: 3, height: 12)
                }
                Text(label.uppercased())
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(isSelected ? Color.DS.onAccent : Color.DS.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.DS.accent : Color.DS.surface, in: .rect(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        FilterChip("All", isSelected: true) {}
        FilterChip("Grass", tint: TypeTint.grass.color, isSelected: false) {}
    }
    .padding()
    .background(Color.DS.viewer)
}
