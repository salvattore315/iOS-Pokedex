import Foundation

/// Where favorites are kept. The features depend on this contract, not on SwiftData.
protocol FavoritesRepository: Sendable {
    /// Adds `favorite`, or replaces the stored one with the same ID.
    func add(_ favorite: Favorite) async throws
    /// Removes the favorite with `id`. Does nothing if there is none.
    func remove(id: Int) async throws
    func isFavorite(id: Int) async throws -> Bool
    /// Every favorite, most recently added first.
    func all() async throws -> [Favorite]
}
