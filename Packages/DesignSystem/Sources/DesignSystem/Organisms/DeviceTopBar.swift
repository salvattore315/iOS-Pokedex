import SwiftUI

/// Header on the red casing: monospaced title on the left, link and battery status on the right.
public struct DeviceTopBar: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.mono(26, weight: .bold))
                .foregroundStyle(Color.DS.onShell)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            DeviceStatus()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}

/// Decorative "LINK" and battery indicator of the device style. Hidden from VoiceOver.
public struct DeviceStatus: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Label("LINK", systemImage: "cellularbars")
            Label("87%", systemImage: "battery.75percent")
        }
        .labelStyle(.titleAndIcon)
        .font(.mono(10))
        .foregroundStyle(Color.DS.onShell)
        .accessibilityHidden(true)
    }
}

#Preview {
    DeviceTopBar("Pokédex").background(Color.DS.shell)
}
