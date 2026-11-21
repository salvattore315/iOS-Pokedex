import Foundation
import Testing
@testable import Pokedex

@MainActor
struct FavoritesViewModelTests {
    private static func favorite(_ id: Int, addedAt seconds: TimeInterval) -> Favorite {
        Favorite(id: id, name: "pokemon-\(id)", types: [.fire], addedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func showsFavoritesNewestFirst() async {
        let viewModel = FavoritesViewModel(favorites: InMemoryFavorites([Self.favorite(1, addedAt: 100), Self.favorite(4, addedAt: 200)]))
        await viewModel.load()
        #expect(viewModel.state.value?.map(\.id) == [4, 1])
    }

    @Test func showsEmptyStateWithoutFavorites() async {
        let viewModel = FavoritesViewModel(favorites: InMemoryFavorites())
        await viewModel.load()
        #expect(viewModel.state == .empty)
    }

    @Test func showsErrorWhenTheStoreFails() async {
        let favorites = InMemoryFavorites()
        favorites.error = InMemoryFavorites.Failure()
        let viewModel = FavoritesViewModel(favorites: favorites)

        await viewModel.load()

        #expect(viewModel.state == .failed(.unexpected))
    }

    @Test func reloadPicksUpChangesMadeElsewhere() async throws {
        let favorites = InMemoryFavorites([Self.favorite(1, addedAt: 100)])
        let viewModel = FavoritesViewModel(favorites: favorites)
        await viewModel.load()

        try await favorites.add(Self.favorite(7, addedAt: 300))
        await viewModel.load()

        #expect(viewModel.state.value?.map(\.id) == [7, 1])
    }

    @Test func removeDeletesFromStoreAndList() async throws {
        let favorites = InMemoryFavorites([Self.favorite(1, addedAt: 100), Self.favorite(4, addedAt: 200)])
        let viewModel = FavoritesViewModel(favorites: favorites)
        await viewModel.load()

        await viewModel.remove(try #require(viewModel.state.value?.first))

        #expect(viewModel.state.value?.map(\.id) == [1])
        #expect(favorites.stored.keys.sorted() == [1])
    }

    @Test func removingTheLastFavoriteShowsEmptyState() async throws {
        let viewModel = FavoritesViewModel(favorites: InMemoryFavorites([Self.favorite(1, addedAt: 100)]))
        await viewModel.load()

        await viewModel.remove(try #require(viewModel.state.value?.first))

        #expect(viewModel.state == .empty)
    }

    @Test func failedRemoveShowsWhatTheStoreHolds() async throws {
        let favorites = InMemoryFavorites([Self.favorite(1, addedAt: 100)])
        let viewModel = FavoritesViewModel(favorites: favorites)
        await viewModel.load()
        let favorite = try #require(viewModel.state.value?.first)
        favorites.error = InMemoryFavorites.Failure()

        await viewModel.remove(favorite)

        // The reload fails too, so the screen shows the error instead of a list that may be stale.
        #expect(viewModel.state == .failed(.unexpected))
        favorites.error = nil
        #expect(try await favorites.all().map(\.id) == [1])
    }
}
