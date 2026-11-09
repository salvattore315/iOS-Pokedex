import SwiftUI
import DesignSystem

/// Stands in for the detail screen until the Detail epic replaces it.
struct DetailPlaceholderView: View {
    let id: Int

    var body: some View {
        StateMessage(
            systemImage: "hammer",
            title: PokemonCard<EmptyView>.formatted(id),
            message: String(localized: "detail.placeholder", defaultValue: "The detail screen is coming soon.")
        )
        .padding(Spacing.xl)
    }
}
