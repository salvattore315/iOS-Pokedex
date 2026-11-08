import SwiftUI

/// Square icon button used in the top bars (back, cry, favorite).
public struct IconButton: View {
    private let systemName: String
    private let accessibilityLabel: String
    private let tint: Color
    private let action: () -> Void

    public init(systemName: String, accessibilityLabel: String, tint: Color = Color.DS.textPrimary, action: @escaping () -> Void) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Color.DS.viewer, in: .rect(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    HStack {
        IconButton(systemName: "chevron.left", accessibilityLabel: "Back") {}
        IconButton(systemName: "speaker.wave.2", accessibilityLabel: "Play cry") {}
        IconButton(systemName: "heart.fill", accessibilityLabel: "Favorite", tint: Color.DS.accent) {}
    }
    .padding()
    .background(Color.DS.shell)
}
