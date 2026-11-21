import Foundation
@testable import Pokedex

/// ``FavoritesRepository`` kept in a dictionary. Set `error` to make every call fail.
final class InMemoryFavorites: FavoritesRepository, @unchecked Sendable {
    struct Failure: Error {}

    private let lock = NSLock()
    private var _favorites: [Int: Favorite] = [:]
    private var _error: Failure?

    init(_ favorites: [Favorite] = []) {
        _favorites = Dictionary(uniqueKeysWithValues: favorites.map { ($0.id, $0) })
    }

    var error: Failure? {
        get { lock.withLock { _error } }
        set { lock.withLock { _error = newValue } }
    }

    var stored: [Int: Favorite] { lock.withLock { _favorites } }

    func add(_ favorite: Favorite) async throws {
        try lock.withLock {
            if let _error { throw _error }
            _favorites[favorite.id] = favorite
        }
    }

    func remove(id: Int) async throws {
        try lock.withLock {
            if let _error { throw _error }
            _favorites[id] = nil
        }
    }

    func isFavorite(id: Int) async throws -> Bool {
        try lock.withLock {
            if let _error { throw _error }
            return _favorites[id] != nil
        }
    }

    func all() async throws -> [Favorite] {
        try lock.withLock {
            if let _error { throw _error }
            return _favorites.values.sorted { $0.addedAt > $1.addedAt }
        }
    }
}
