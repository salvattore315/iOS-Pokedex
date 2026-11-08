import SwiftUI

/// Region selector tab in "Where to find it".
public struct RegionTab: View {
    private let label: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.mono(10, weight: .bold))
                .foregroundStyle(isSelected ? Color.DS.module : Color.DS.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.DS.textPrimary : Color.DS.surfaceMuted, in: .rect(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        RegionTab("Kanto", isSelected: true) {}
        RegionTab("Johto", isSelected: false) {}
    }
    .padding()
    .background(Color.DS.module)
}
