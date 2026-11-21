import Foundation
import Observation

/// Drives the favorites tab. Favorites come from the local store, so the tab works offline.
@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var state: ViewState<[Favorite]> = .idle

    private let favorites: any FavoritesRepository

    init(favorites: any FavoritesRepository) {
        self.favorites = favorites
    }

    /// Reads the favorites again. Called every time the tab appears, because the detail
    /// screen can add or remove favorites in the meantime.
    func load() async {
        // Keep the current list on screen while reloading instead of flashing a spinner.
        if state.value == nil { state = .loading }
        do {
            show(try await favorites.all())
        } catch {
            state = .failed(.unexpected)
        }
    }

    /// Removes `favorite` from the store and from the list.
    func remove(_ favorite: Favorite) async {
        do {
            try await favorites.remove(id: favorite.id)
        } catch {
            // The store may not have changed; show what it actually holds.
            await load()
            return
        }
        show((state.value ?? []).filter { $0.id != favorite.id })
    }

    private func show(_ items: [Favorite]) {
        state = items.isEmpty ? .empty : .loaded(items)
    }
}
