import Foundation
import SwiftData

/// ``FavoritesRepository`` backed by SwiftData, on a background context.
@ModelActor
actor FavoritesStore: FavoritesRepository {
    func add(_ favorite: Favorite) throws {
        if let existing = try entry(id: favorite.id) {
            existing.name = favorite.name
            existing.typeNames = favorite.types.map(\.rawValue)
            existing.addedAt = favorite.addedAt
        } else {
            modelContext.insert(FavoritePokemon(favorite))
        }
        try modelContext.save()
    }

    func remove(id: Int) throws {
        guard let existing = try entry(id: id) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func isFavorite(id: Int) throws -> Bool {
        try modelContext.fetchCount(Self.descriptor(id: id)) > 0
    }

    func all() throws -> [Favorite] {
        let descriptor = FetchDescriptor<FavoritePokemon>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.favorite)
    }

    private func entry(id: Int) throws -> FavoritePokemon? {
        try modelContext.fetch(Self.descriptor(id: id)).first
    }

    private static func descriptor(id: Int) -> FetchDescriptor<FavoritePokemon> {
        var descriptor = FetchDescriptor<FavoritePokemon>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return descriptor
    }
}
