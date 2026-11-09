import SwiftUI
import DesignSystem

/// Stands in for the favorites screen until the Favorites epic replaces it.
struct FavoritesPlaceholderView: View {
    var body: some View {
        StateMessage(
            systemImage: "heart",
            title: String(localized: "favorites.placeholder.title", defaultValue: "Favorites"),
            message: String(localized: "favorites.placeholder.message", defaultValue: "Coming soon.")
        )
        .padding(Spacing.xl)
    }
}
