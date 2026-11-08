import SwiftUI

/// Top bar of the detail screen: back, device status, cry and favorite.
public struct DetailTopBar: View {
    private let isFavorite: Bool
    private let isCryAvailable: Bool
    private let onBack: () -> Void
    private let onCry: () -> Void
    private let onFavorite: () -> Void

    public init(
        isFavorite: Bool,
        isCryAvailable: Bool = true,
        onBack: @escaping () -> Void,
        onCry: @escaping () -> Void,
        onFavorite: @escaping () -> Void
    ) {
        self.isFavorite = isFavorite
        self.isCryAvailable = isCryAvailable
        self.onBack = onBack
        self.onCry = onCry
        self.onFavorite = onFavorite
    }

    private var favoriteLabel: String {
        isFavorite
            ? String(localized: "Remove from favorites", bundle: .module)
            : String(localized: "Add to favorites", bundle: .module)
    }

    public var body: some View {
        HStack {
            IconButton(systemName: "chevron.left", accessibilityLabel: String(localized: "Back", bundle: .module), action: onBack)
            Spacer()
            DeviceStatus()
            Spacer()
            HStack(spacing: Spacing.sm) {
                if isCryAvailable {
                    IconButton(systemName: "speaker.wave.2", accessibilityLabel: String(localized: "Play cry", bundle: .module), action: onCry)
                }
                IconButton(
                    systemName: isFavorite ? "heart.fill" : "heart",
                    accessibilityLabel: favoriteLabel,
                    tint: Color.DS.accent,
                    action: onFavorite
                )
                .symbolEffect(.bounce, value: isFavorite)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}

#Preview {
    DetailTopBar(isFavorite: true, onBack: {}, onCry: {}, onFavorite: {}).background(Color.DS.shell)
}
