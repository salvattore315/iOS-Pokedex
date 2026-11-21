import Foundation
import SwiftData

/// A stored favorite. Types are kept as PokéAPI names so the model only holds plain values.
@Model
final class FavoritePokemon {
    @Attribute(.unique) var id: Int
    var name: String
    var typeNames: [String]
    var addedAt: Date

    init(id: Int, name: String, typeNames: [String], addedAt: Date) {
        self.id = id
        self.name = name
        self.typeNames = typeNames
        self.addedAt = addedAt
    }

    convenience init(_ favorite: Favorite) {
        self.init(id: favorite.id, name: favorite.name, typeNames: favorite.types.map(\.rawValue), addedAt: favorite.addedAt)
    }

    var favorite: Favorite {
        Favorite(id: id, name: name, types: typeNames.compactMap(PokemonType.init(rawValue:)), addedAt: addedAt)
    }
}
