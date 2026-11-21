import Foundation
import SwiftData
import Testing
@testable import Pokedex

struct FavoritesStoreTests {
    private let store: FavoritesStore

    init() throws {
        store = try makeInMemoryFavoritesStore()
    }

    private static func favorite(_ id: Int, addedAt seconds: TimeInterval = 0) -> Favorite {
        Favorite(id: id, name: "pokemon-\(id)", types: [.grass, .poison], addedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func startsEmpty() async throws {
        #expect(try await store.all().isEmpty)
        #expect(try await store.isFavorite(id: 1) == false)
    }

    @Test func addKeepsEveryField() async throws {
        let favorite = Self.favorite(1, addedAt: 100)
        try await store.add(favorite)

        #expect(try await store.isFavorite(id: 1))
        #expect(try await store.all() == [favorite])
    }

    @Test func addingTwiceKeepsOneEntryWithTheLatestData() async throws {
        try await store.add(Self.favorite(1, addedAt: 100))
        let updated = Favorite(id: 1, name: "bulbasaur", types: [.grass], addedAt: Date(timeIntervalSince1970: 200))
        try await store.add(updated)

        #expect(try await store.all() == [updated])
    }

    @Test func removeDeletesOnlyThatFavorite() async throws {
        try await store.add(Self.favorite(1))
        try await store.add(Self.favorite(4))

        try await store.remove(id: 1)

        #expect(try await store.isFavorite(id: 1) == false)
        #expect(try await store.all().map(\.id) == [4])
    }

    @Test func removingAMissingFavoriteDoesNothing() async throws {
        try await store.add(Self.favorite(1))
        try await store.remove(id: 99)
        #expect(try await store.all().map(\.id) == [1])
    }

    @Test func allIsSortedByDateNewestFirst() async throws {
        try await store.add(Self.favorite(7, addedAt: 200))
        try await store.add(Self.favorite(1, addedAt: 300))
        try await store.add(Self.favorite(4, addedAt: 100))

        #expect(try await store.all().map(\.id) == [1, 7, 4])
    }
}

/// An empty favorites store that lives only in memory.
func makeInMemoryFavoritesStore() throws -> FavoritesStore {
    let container = try ModelContainer(
        for: FavoritePokemon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return FavoritesStore(modelContainer: container)
}
