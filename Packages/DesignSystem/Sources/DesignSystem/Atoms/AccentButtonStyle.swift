import SwiftUI

/// Primary button: yellow accent with dark monospaced text. Used for "Retry".
public struct AccentButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(12, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(Color.DS.onAccent)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color.DS.accent, in: .rect(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

public extension ButtonStyle where Self == AccentButtonStyle {
    static var accent: AccentButtonStyle { AccentButtonStyle() }
}

#Preview {
    Button("Retry") {}.buttonStyle(.accent).padding()
}
