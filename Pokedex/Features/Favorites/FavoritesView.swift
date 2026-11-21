import SwiftUI
import DesignSystem

/// The favorites tab: the saved Pokémon, most recent first. Swipe a card to remove it.
struct FavoritesView: View {
    @State private var viewModel: FavoritesViewModel

    init(viewModel: FavoritesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            DeviceTopBar(String(localized: "favorites.title", defaultValue: "Favorites"))
            content
        }
        .background(Color.DS.surface)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let favorites):
            List {
                ForEach(favorites) { favorite in
                    row(favorite)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .empty:
            message(StateMessage(
                systemImage: "heart",
                title: String(localized: "favorites.empty.title", defaultValue: "No favorites yet"),
                message: String(localized: "favorites.empty.message", defaultValue: "Tap the heart on a Pokémon to save it here.")
            ))
        case .failed(let error):
            message(StateMessage(
                systemImage: "exclamationmark.triangle",
                title: error.title,
                message: error.message,
                actionTitle: String(localized: "action.retry", defaultValue: "Retry"),
                action: { Task { await viewModel.load() } }
            ))
        }
    }

    private func row(_ favorite: Favorite) -> some View {
        // The link is hidden behind the card: a visible one would add a disclosure chevron.
        ZStack {
            NavigationLink(value: favorite.id) { EmptyView() }.opacity(0)
            PokemonCard(name: favorite.name, number: favorite.id, types: favorite.types.map(\.badge)) {
                ArtworkImage(url: PokemonSummary(id: favorite.id, name: favorite.name).artworkURL, priority: .utility)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.remove(favorite) }
            } label: {
                Label(String(localized: "favorites.remove", defaultValue: "Remove"), systemImage: "trash")
            }
        }
    }

    private func message(_ message: StateMessage) -> some View {
        message
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
